defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view
  alias ChoreRunnerUI.Components.{ChoreItemComponent, ChoreModalComponent}
  @styles File.read!(Application.app_dir(:chore_runner, "priv/css/main.css"))

  defp styles, do: @styles

  defp first_log([{log, ts} | _]) do
    "[#{ts}] #{log}"
  end

  defp first_log(_), do: ""

  defp download_link(download_plug_path, download),
    do:
      ChoreRunner.Downloads.StorageService.file_url(download,
        download_plug_path: download_plug_path
      )
end
