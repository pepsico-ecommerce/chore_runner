defmodule ChoreRunner.Chore do
  @moduledoc """
  Behaviour and DSL for chores.
  """
  require ChoreRunner.DSL
  alias ChoreRunner.{DSL, Input}

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
            values: %{}

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
          values: %{atom() => number()}
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
  The input functions provided are `string`, `int`, `float`, `file`, and `bool`.
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
  @optional_callbacks result_handler: 1

  def validate_input(%__MODULE__{mod: mod}, input) do
    expected_inputs = mod.inputs

    Enum.reduce(input, {%{}, []}, fn {key, val}, {validated_inputs, errors_acc} ->
      with {:ok, {type, name, opts}} <- verify_valid_input_name(expected_inputs, key),
           {:ok, validated_value} <- validate_input(name, val, type, opts) do
        {Map.put(validated_inputs, name, validated_value), errors_acc}
      else
        {:error, :invalid_input_name} ->
          {validated_inputs, errors_acc}

        {:error, name, errors} ->
          {validated_inputs, [{name, errors} | errors_acc]}
      end
    end)
    |> case do
      {final_inputs, []} -> {:ok, final_inputs}
      {_, errors} -> {:error, errors}
    end
  end

  defp verify_valid_input_name(expected_inputs, key) do
    Enum.find_value(expected_inputs, fn {type, name, opts} ->
      if name == key or "#{name}" == key do
        {:ok, {type, name, opts}}
      else
        false
      end
    end)
    |> case do
      nil -> {:error, :invalid_input_name}
      {:ok, res} -> {:ok, res}
    end
  end

  defp validate_input(name, value, type, opts) do
    [(&Input.validate_field(type, &1)) | Keyword.get(opts, :validators, [])]
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
end
