defmodule ChoreRunner.Chore do
  @moduledoc """
  Behaviour and DSL for chores.
  """
  require ChoreRunner.DSL
  alias ChoreRunner.DSL
  alias ChoreRunner.Input

  defstruct extra_data: %{},
            finished_at: nil,
            id: nil,
            inputs: %{},
            logs: [],
            mod: nil,
            reporter: nil,
            result: nil,
            started_at: nil,
            task: nil,
            values: %{},
            downloads: []

  defmacro __using__(opts), do: DSL.using(opts)

  @type unix_timestamp :: integer()
  @type t :: %__MODULE__{
          extra_data: map(),
          finished_at: DateTime.t(),
          id: String.t(),
          inputs: map(),
          logs: [{unix_timestamp, String.t()}],
          mod: module(),
          reporter: pid(),
          result: any(),
          started_at: DateTime.t(),
          task: Task.t(),
          values: %{atom() => number()},
          downloads: [ChoreRunner.Downloads.StorageService.file()]
        }

  @doc """
  An optional callback function for defining a chore restriction.


  The restriction can be either :none, :self, or :global
  - `:none` is no restrictions
  - `:self` prevents more than one of the same chore from running simultaneously across all connected nodes
  - `:global` prevents more than one of all chores with the restriction `:global` from running simultaneously across all connected nodes. This restriction does not affect non-`:global` chores.
  If this callback is not defined, the default return is `:self`
  """
  @callback restriction :: :none | :self | :global
  @doc """
  An optional callback function for defining a chore's inputs.


  Expects a list of input function calls.
  The input functions provided are `string`, `int`, `float`, `file`, `bool`, and `selectbox`.
  All input functions follow the same syntax.
  For example:
  ```
  def inputs do
    [
      string(:name),
      int(:name2, [some: :option])
    ]
  end
  ```
  The supported options are
  - `:description` — a string description of the input, for UI use
  - `:default` — a value used when the caller omits this input and prefilled in the UI
  - `:depends_on` — a list of inputs declared earlier that must be valid before this input is
    shown and validated. One-arity `selectbox` option providers receive their validated values.
  - `:visible?` — a one-arity function receiving the `:depends_on` values; the input is shown
    and validated only when it returns `true`. Requires `:depends_on`.
  - `:validators` — a list of anonymous or captured validator functions.
    Valiator functions should accept a single argument as a parameter, but can return a variety of things, including:
    - an `{:ok, value}`, or `{:error, reason}` tuple
    - an `:ok` or `:error` atom
    - a `true` or `false`
    - any erlang value, or nil
    The positive values (`:ok`, `true`, non-falsey values) pass validation.
    The negative values (`:error`, `false`, `nil`) fail validation
    If a value is passed back as part of an {:ok, value} tuple, or by itself, that value is treated as the new value of the given input. This way, validators can also transform input if needed.
  If this callback is not defined, the default return is `[]`, or no inputs.
  """
  @callback inputs :: [Input.t()]

  @doc """
  An optional callback for validating or transforming the complete input map.

  This callback runs after defaults, type casting, and individual field validators have
  succeeded. It receives only declared inputs with atom keys.

  Return `{:ok, validated_inputs}` to continue or `{:error, keyword_errors}` to reject the
  inputs. Each error must use a declared input name and a non-empty list of reasons, for
  example `{:error, number_of_orders: ["must be even"]}`.
  """
  @callback validate_inputs(map()) :: {:ok, map()} | {:error, [{atom(), [any()]}]}

  @doc """
  A non-optional callback used to contain the main Chore logic.


  Accepts a map of input, always atom keyed. (When calling ChoreRunner.run_chore/2, a string keyed map will be intelligently converted to an atom-keyed map automatically)
  Only keys defined in the `inputs/0` callback will be present in the input map, but defined inputs are not garaunteed to be present.
  The chore callback has access to several `Reporter` functions, used for live chore metrics and loggin.
  These functions are:
  - `log(message)` — Logs a string message with timestamp
  - `set_counter(name, value)` — Sets a named counter, expects an atom for a name and a number for a value
  - `inc_counter(name, inc_value)` — Increments a named counter. If the counter does not exist, it will default to 0, and then be incremented. Used negative values for decrements.
  - `report_failed(reason_message)` — Fails a chore, marking it as failed.
  The return value of the `run/1` callback will be stored in the chore struct and forwarded to the final chore handling function.
  """
  @callback run(map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Optional callback to be called once the chore has been completed.
  """
  @callback result_handler(t()) :: any()
  @callback available?(t()) :: boolean()
  @callback instructions() :: String.t() | nil
  @callback persist_inputs_in_url?() :: boolean()
  @optional_callbacks result_handler: 1,
                      available?: 1,
                      instructions: 0,
                      persist_inputs_in_url?: 0,
                      validate_inputs: 1

  @doc "Returns explicit chore instructions, falling back to the module documentation."
  @spec instructions_for(module()) :: String.t() | nil
  def instructions_for(chore) do
    chore
    |> explicit_instructions()
    |> case do
      nil -> module_doc(chore)
      instructions -> instructions
    end
  end

  @type resolved_inputs :: %{
          validated: map(),
          errors: [{atom(), [any()]}],
          active_inputs: [Input.t()],
          select_options: %{atom() => Input.select_options()}
        }

  @doc """
  Resolves a chore's inputs in declaration order.

  An input is active when every input in its `:depends_on` list is active and valid, and its
  `:visible?` function (if any) returns `true`. Inactive inputs are not validated and are
  left out of `validated`. Select options are resolved once per active select, using the
  validated values of its dependencies. `errors` includes cross-field errors from
  `validate_inputs/1`, which runs only when every field is valid.
  """
  @spec resolve_inputs(t(), map()) :: resolved_inputs()
  def resolve_inputs(%__MODULE__{mod: mod}, input) do
    expected_inputs = mod.inputs()
    :ok = Input.validate_dependencies!(expected_inputs)
    input = put_default_values(input, expected_inputs)

    resolved =
      Enum.reduce(
        expected_inputs,
        %{validated: %{}, errors: [], active_inputs: [], select_options: %{}},
        &resolve_input(&1, &2, input)
      )

    resolved = %{
      resolved
      | errors: Enum.reverse(resolved.errors),
        active_inputs: Enum.reverse(resolved.active_inputs)
    }

    case resolved do
      %{errors: [], validated: validated} ->
        case validate_inputs(mod, validated, expected_inputs) do
          {:ok, validated} -> %{resolved | validated: validated}
          {:error, errors} -> %{resolved | errors: errors}
        end

      resolved ->
        resolved
    end
  end

  def validate_input(%__MODULE__{} = chore, input) do
    case resolve_inputs(chore, input) do
      %{errors: [], validated: validated} -> {:ok, validated}
      %{errors: errors} -> {:error, errors}
    end
  end

  defp resolve_input({type, name, opts} = declared_input, resolved, input) do
    dependencies = Input.dependencies(opts)
    dependency_values = Map.take(resolved.validated, dependencies)

    if active_input?(opts, dependencies, dependency_values) do
      {opts, resolved} = resolve_select_options(type, name, opts, dependency_values, resolved)
      resolved = %{resolved | active_inputs: [declared_input | resolved.active_inputs]}

      with {:ok, value} <- fetch_input(input, name),
           {:ok, validated_value} <- validate_input(name, value, type, opts) do
        %{resolved | validated: Map.put(resolved.validated, name, validated_value)}
      else
        :error -> resolved
        {:error, name, errors} -> %{resolved | errors: [{name, errors} | resolved.errors]}
      end
    else
      resolved
    end
  end

  defp active_input?(opts, dependencies, dependency_values) do
    Enum.all?(dependencies, &Map.has_key?(dependency_values, &1)) and
      Input.visible?(opts, dependency_values)
  end

  defp resolve_select_options(:select, name, opts, dependency_values, resolved) do
    options = Input.select_options(opts, dependency_values)

    {Keyword.put(opts, :options, options),
     %{resolved | select_options: Map.put(resolved.select_options, name, options)}}
  end

  defp resolve_select_options(_type, _name, opts, _dependency_values, resolved),
    do: {opts, resolved}

  defp fetch_input(input, name) do
    case Map.fetch(input, name) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(input, to_string(name))
    end
  end

  defp validate_inputs(mod, inputs, expected_inputs) do
    result =
      if function_exported?(mod, :validate_inputs, 1) do
        mod.validate_inputs(inputs)
      else
        {:ok, inputs}
      end

    validate_inputs_result(result, mod, expected_inputs)
  end

  defp validate_inputs_result({:ok, inputs}, mod, expected_inputs) when is_map(inputs) do
    declared_inputs = declared_input_names(expected_inputs)
    unknown_inputs = inputs |> Map.keys() |> Enum.reject(&(&1 in declared_inputs))

    if unknown_inputs == [] do
      {:ok, inputs}
    else
      raise ArgumentError,
            "#{inspect(mod)}.validate_inputs/1 returned undeclared input keys: " <>
              "#{inspect(unknown_inputs)}; declared inputs: #{inspect(declared_inputs)}"
    end
  end

  defp validate_inputs_result({:error, errors} = result, mod, expected_inputs)
       when is_list(errors) do
    declared_inputs = declared_input_names(expected_inputs)

    if Keyword.keyword?(errors) do
      unknown_fields =
        errors |> Keyword.keys() |> Enum.uniq() |> Enum.reject(&(&1 in declared_inputs))

      if unknown_fields != [] do
        raise ArgumentError,
              "#{inspect(mod)}.validate_inputs/1 returned errors for undeclared inputs: " <>
                "#{inspect(unknown_fields)}; declared inputs: #{inspect(declared_inputs)}"
      end

      if errors != [] and
           Enum.all?(errors, fn {_field, reasons} -> is_list(reasons) and reasons != [] end) do
        {:error, errors}
      else
        raise_invalid_validate_inputs_result(mod, result)
      end
    else
      raise_invalid_validate_inputs_result(mod, result)
    end
  end

  defp validate_inputs_result(result, mod, _expected_inputs) do
    raise_invalid_validate_inputs_result(mod, result)
  end

  defp declared_input_names(expected_inputs) do
    Enum.map(expected_inputs, fn {_type, name, _opts} -> name end)
  end

  defp raise_invalid_validate_inputs_result(mod, result) do
    raise ArgumentError,
          "#{inspect(mod)}.validate_inputs/1 must return {:ok, map} or " <>
            "{:error, keyword errors with non-empty reason lists}; got: #{inspect(result)}"
  end

  defp validate_input(name, value, type, opts) do
    [(&Input.validate_field(type, &1, opts)) | Keyword.get(opts, :validators, [])]
    |> Enum.reduce({value, []}, fn validator, {val, errors} ->
      case validator.(val) do
        {:ok, validated_value} -> {validated_value, errors}
        :ok -> {val, errors}
        true -> {val, errors}
        {:error, reason} -> {val, [reason | errors]}
        false -> {val, ["invalid" | errors]}
        nil -> {val, ["invalid" | errors]}
        other -> {other, errors}
      end
    end)
    |> case do
      {final_value, [] = _no_errors} -> {:ok, final_value}
      {_invalid, errors} -> {:error, name, errors}
    end
  end

  defp put_default_values(input, expected_inputs) do
    expected_inputs
    |> Input.default_values()
    |> Enum.reduce(input, fn {name, value}, acc ->
      if Map.has_key?(acc, name) or Map.has_key?(acc, to_string(name)) do
        acc
      else
        Map.put(acc, name, value)
      end
    end)
  end

  defp explicit_instructions(chore) do
    if function_exported?(chore, :instructions, 0) do
      chore.instructions()
      |> normalize_instructions()
    end
  end

  defp module_doc(chore) do
    case Code.fetch_docs(chore) do
      {:docs_v1, _annotation, _language, _format, %{} = docs, _metadata, _entries} ->
        docs
        |> Map.get("en", docs |> Map.values() |> List.first())
        |> normalize_instructions()

      {:docs_v1, _annotation, _language, _format, doc, _metadata, _entries}
      when is_binary(doc) ->
        normalize_instructions(doc)

      _other ->
        nil
    end
  end

  defp normalize_instructions(instructions) when is_binary(instructions) do
    case String.trim(instructions) do
      "" -> nil
      instructions -> instructions
    end
  end

  defp normalize_instructions(_instructions), do: nil
end
