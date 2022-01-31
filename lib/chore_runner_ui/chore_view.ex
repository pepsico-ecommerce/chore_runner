defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view
  alias ChoreRunnerUI.Components.{ChoreItemComponent, ChoreModalComponent}
  @styles File.read!(Application.app_dir(:chore_runner, "priv/css/main.css"))

  defp styles, do: @styles

  defp log({log, ts, opts}) do
    log
    |> maybe_add_timestamp(ts, opts)
    |> maybe_allow_raw_html(opts)
  end

  defp first_log([log | _]) do
    log(log)
  end

  defp first_log(_), do: ""

  defp maybe_add_timestamp(log, _ts, %{timestamp: false}) do
    log
  end

  defp maybe_add_timestamp(log, ts, _) do
    "[#{ts}] #{log}"
  end

  defp maybe_allow_raw_html(log, %{html: true}) do
    raw(log)
  end

  defp maybe_allow_raw_html(log, _) do
    log
  end
end
