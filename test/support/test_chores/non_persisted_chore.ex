defmodule ChoreRunner.TestChores.NonPersistedChore do
  use ChoreRunner.Chore

  def inputs do
    [string(:message, default: "initial")]
  end

  def run(inputs), do: {:ok, inputs}
end
