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

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)

  defp input_options(class), do: [class: class, phx_update: "ignore"]

  defp checkbox_input_options(form, key, browser_managed_checkboxes?) do
    checked =
      form
      |> Phoenix.HTML.Form.input_value(key)
      |> then(&Phoenix.HTML.Form.normalize_value("checkbox", &1))

    input_options = [class: "chore-form-input chore-form-checkbox", checked: checked]

    if browser_managed_checkboxes? do
      Keyword.put(input_options, :phx_update, "ignore")
    else
      input_options
    end
  end

  defp select_input_options(opts) do
    input_opts = input_options("chore-form-input chore-form-select")

    case Keyword.fetch(opts, :prompt) do
      {:ok, prompt} -> Keyword.put(input_opts, :prompt, prompt)
      :error -> input_opts
    end
  end
end
