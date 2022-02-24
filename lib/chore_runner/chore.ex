defmodule ChoreRunner.Chore do
  @moduledoc """
  Behaviour and DSL for chores.
  """
  require ChoreRunner.DSL
  alias ChoreRunner.{DSL, Input}

  defstruct id: nil,
            mod: nil,
            logs: [],
            values: %{},
            task: nil,
            reporter: nil,
            started_at: nil,
            finished_at: nil,
            result: nil

  defmacro __using__(_args), do: DSL.using()

  @type unix_timestamp :: integer()
  @type t :: %__MODULE__{
          id: String.t(),
          mod: module(),
          logs: [{unix_timestamp, String.t()}],
          values: %{atom() => number()},
          task: Task.t(),
          reporter: pid(),
          started_at: DateTime.t(),
          finished_at: DateTime.t(),
          result: any()
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

  def validate_input(%__MODULE__{mod: mod}, input) do
    expected_inputs = mod.inputs

    Enum.reduce(input, {%{}, []}, fn {key, val}, {validated_inputs, errors_acc} ->
      with {:ok, input} <- verify_valid_input_name(expected_inputs, key),
           name <- input |> Tuple.to_list() |> Enum.at(1),
           {:ok, validated_value} <- do_validate_input(val, input) do
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
    Enum.find_value(expected_inputs, fn
      {type, name, args, opts} ->
        if name == key or "#{name}" == key do
          {:ok, {type, name, args, opts}}
        else
          false
        end

      {type, name, opts} ->
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

  defp do_validate_input(value, {type, name, opts}) do
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

  defp do_validate_input(value, {type, name, args, opts}) do
    [(&Input.validate_field(type, &1, args)) | Keyword.get(opts, :validators, [])]
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
      {final_value, [] = _no_errors} ->
        {:ok, final_value}

      {_invalid, errors} ->
        {:error, name, errors}
    end
  end
end
