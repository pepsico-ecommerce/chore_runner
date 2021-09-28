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

  @callback restriction :: :none | :self | :global
  @callback inputs :: [Input.t()]
  @callback run(map()) :: {:ok, any()} | {:error, any()}

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
      end
    end)
    |> case do
      {final_value, [] = _no_errors} -> {:ok, final_value}
      {_invalid, errors} -> {:error, name, errors}
    end
  end
end
