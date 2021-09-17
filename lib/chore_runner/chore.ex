defmodule ChoreRunner.Chore do
  @moduledoc """
  Behaviour and DSL for chores.
  """
  require ChoreRunner.DSL
  alias ChoreRunner.DSL

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

  @callback restriction :: :none | :self | :global
  @callback run(map()) :: {:ok, any()} | {:error, any()}

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

  def validate_input(%__MODULE__{mod: _mod}, input) do
    {:ok, input}
  end
end
