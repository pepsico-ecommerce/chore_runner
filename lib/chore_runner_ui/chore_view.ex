defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view
  alias ChoreRunnerUI.Components.ChoreItemComponent
  @styles File.read!(Application.app_dir(:chore_runner, "priv/css/main.css"))

  defp styles, do: @styles

  defp first_log([{log, ts} | _]) do
    "[#{ts}] #{log}"
  end

  defp first_log(_), do: ""
end
