defmodule ChoreRunner.DSL do
  @moduledoc """
  Macros which enable the chore DSL
  """

  def using do
    quote do
      @behaviour ChoreRunner.Chore

      import ChoreRunner.Reporter,
        only: [
          report_failed: 1,
          log: 1,
          set_counter: 2,
          inc_counter: 2
        ]

      import ChoreRunner.Input,
        only: [
          string: 2,
          int: 2,
          float: 2,
          file: 2,
          bool: 2
        ]

      def restriction, do: :self
      def inputs, do: []
      defoverridable inputs: 0, restriction: 0
    end
  end
end
