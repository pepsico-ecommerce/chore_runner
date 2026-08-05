defmodule ChoreRunnerUI.ChoreView do
  use ChoreRunnerUI, :view

  alias ChoreRunner.Input
  alias ChoreRunnerUI.Components.ChoreItemComponent
  alias ChoreRunnerUI.Components.ChoreModalComponent

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

  defp select_options(opts), do: Input.select_options(opts)

  defp input_options(class, persist_inputs_in_url?) do
    if persist_inputs_in_url? do
      [class: class]
    else
      [class: class, phx_update: "ignore"]
    end
  end

  defp select_input_options(opts, persist_inputs_in_url?) do
    input_opts = input_options("chore-form-input chore-form-select", persist_inputs_in_url?)

    case Keyword.fetch(opts, :prompt) do
      {:ok, prompt} -> Keyword.put(input_opts, :prompt, prompt)
      :error -> input_opts
    end
  end
end
