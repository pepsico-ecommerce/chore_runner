defmodule ChoreRunner.TestChores.FormChore do
  @moduledoc "Choose values to exercise the generated chore form."

  use ChoreRunner.Chore, persist_inputs_in_url?: true

  def inputs do
    [
      selectbox(:static_choice, [{"Alpha", :alpha}, {"Beta", :beta}],
        default: :beta,
        description: "A hardcoded selection"
      ),
      selectbox(:dynamic_choice, &dynamic_options/0,
        prompt: "Choose a dynamic value",
        description: "Options returned by the chore"
      ),
      int(:count, default: 5),
      bool(:commit?, default: false),
      file(:upload)
    ]
  end

  def run(inputs), do: {:ok, inputs}

  defp dynamic_options, do: [{"One", 1}, {"Two", 2}]
end
