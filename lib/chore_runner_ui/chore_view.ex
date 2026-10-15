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

  defp format_error(error) when is_binary(error), do: error
  defp format_error(:not_in_options), do: "Select one of the available options"
  defp format_error(:invalid), do: "Value is invalid"
  defp format_error(:does_not_exist), do: "File does not exist"
  defp format_error(error), do: inspect(error)

  defp input_options(class), do: [class: class, phx_update: "ignore"]

  # Inputs stay `phx-update="ignore"` so URL patches never overwrite browser values. A
  # dependent input's id changes with its dependency values instead, so LiveView replaces
  # it with freshly rendered options and value whenever a dependency changes.
  defp dependent_input_id(form, key, opts, form_values) do
    case Input.dependencies(opts) do
      [] ->
        []

      dependencies ->
        attrs = Map.get(form_values, "chore_attrs", %{})
        values = Enum.map(dependencies, &Map.get(attrs, to_string(&1)))
        [id: "#{Phoenix.HTML.Form.input_id(form, key)}_#{:erlang.phash2(values)}"]
    end
  end

  defp label_options(form, key, opts, form_values) do
    case dependent_input_id(form, key, opts, form_values) do
      [id: id] -> [class: "chore-form-label", for: id]
      [] -> [class: "chore-form-label"]
    end
  end

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
