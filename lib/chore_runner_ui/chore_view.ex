defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view
  alias ChoreRunnerUI.Components.ChoreItemComponent
  @styles File.read!(Application.app_dir(:chore_runner, "priv/css/main.css"))

  defp styles, do: @styles
  # defp styles, do: File.read!(Application.app_dir(:chore_runner, "priv/css/main.css"))

  defp first_log([{ts, log} | _]) do
    "[#{ts}] #{log}"
  end

  defp first_log(_), do: ""
end
