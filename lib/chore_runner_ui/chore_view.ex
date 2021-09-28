defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view
  alias ChoreRunnerUI.Components.ChoreItemComponent
  @styles File.read!(Application.app_dir(:chore_runner, "priv/css/chore.css"))

  defp styles, do: @styles
  # defp styles, do: ""

  defp first_log([{ts, log} | _]) do
    "[#{ts}] #{log}"
  end

  defp first_log(_), do: ""
end
