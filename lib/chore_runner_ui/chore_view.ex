defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view
  alias ChoreRunnerUI.Components.ChoreItemComponent

  @priv_styles "css/chore.css"

  defp styles, do: File.read!(Path.join(:code.priv_dir(:chore_runner), @styles))
  # defp styles, do: ""

  defp first_log([{ts, log} | _]) do
    "[#{ts}] #{log}"
  end

  defp first_log(_), do: ""
end
