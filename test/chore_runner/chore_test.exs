defmodule ChoreRunner.ChoreTest do
  use ExUnit.Case, async: true

  alias ChoreRunner.Chore

  defmodule ExplicitInstructionsChore do
    @moduledoc "Module documentation"

    use ChoreRunner.Chore

    def instructions, do: "Explicit instructions"
    def run(inputs), do: {:ok, inputs}
  end

  defmodule ModuleDocChore do
    @moduledoc "Module documentation"

    use ChoreRunner.Chore

    def run(inputs), do: {:ok, inputs}
  end

  test "prefers explicit instructions" do
    assert Chore.instructions_for(ExplicitInstructionsChore) == "Explicit instructions"
  end

  test "falls back to module documentation" do
    assert ModuleDocChore.instructions() == "Module documentation"
    assert Chore.instructions_for(ModuleDocChore) == "Module documentation"
  end
end
