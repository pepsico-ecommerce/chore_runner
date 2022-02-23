defmodule ChoreRunner.DSL do
  @moduledoc """
  Macros which enable the chore DSL
  """

  def using do
    quote do
      alias ChoreRunner.Chore
      @behaviour Chore

      import ChoreRunner.Reporter,
        only: [
          report_failed: 1,
          log: 1,
          log: 2,
          set_counter: 2,
          inc_counter: 2
        ]

      import ChoreRunner.Input,
        only: [
          string: 2,
          int: 2,
          float: 2,
          file: 2,
          bool: 2,
          select: 2,
          select: 3,
          string: 1,
          int: 1,
          float: 1,
          file: 1,
          bool: 1
        ]

      def restriction, do: :self
      def inputs, do: []

      def validate_input(input),
        do: Chore.validate_input(%Chore{mod: __MODULE__}, input)

      defoverridable inputs: 0, restriction: 0
    end
  end
end
