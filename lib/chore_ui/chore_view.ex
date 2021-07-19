defmodule ChoreUI.ChoreView do
  use ChoreUI, :view
  alias ChoreUi.Components.ChoreItemComponent

  @styles Path.join(:code.priv_dir(:chore), "css/chore.css")

  defp styles, do: File.read!(@styles)
  # defp styles, do: ""

  defp first_log([{ts, log} | _]) do
    "[#{ts}] #{log}"
  end

  defp first_log(_), do: ""
end
