defmodule ChoreRunner.Chore do
  @moduledoc """
  Behaviour and DSL for chores.
  """
  require ChoreRunner.DSL
  alias ChoreRunner.DSL
  defstruct logs: [], percent: 0, scalar: 0
  defmacro __using__(_args), do: DSL.using()

  @callback restriction :: :none | :self | :global
  @callback run(map()) :: {:ok, any()} | {:error, any()}

  @type unix_timestamp :: integer()
  @type t :: %__MODULE__{
          logs: [{unix_timestamp, String.t()}],
          percent: integer(),
          scalar: integer()
        }
end
