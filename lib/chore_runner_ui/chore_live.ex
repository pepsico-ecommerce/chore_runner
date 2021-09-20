defmodule ChoreRunnerUI.ChoreLive do
  use ChoreRunnerUI, :live
  alias ChoreRunnerUI.ChoreView
  require Logger

  def mount(params, session, socket) do
    subscribe_to_pubsub(session)
    chores = list_chores(session)

    {selected_chore_name, selected_chore} =
      case Map.to_list(chores) do
        [{selected_chore_name, selected_chore} | _] -> {selected_chore_name, selected_chore}
        _ -> {nil, nil}
      end

    socket =
      assign(socket,
        chores: chores,
        form_chores: Map.keys(chores),
        running_chores: ChoreRunner.list_running_chores(),
        params: params,
        session: session,
        inputs: [],
        file_inputs: [],
        currently_selected_chore: selected_chore,
        form_selected_chore: selected_chore_name,
        chore_errors: %{},
        is_chore_valid: true
      )
      |> set_inputs(selected_chore && selected_chore.inputs())

    {:ok, socket}
  end

  def render(assigns) do
    ChoreView.render("index.html", assigns)
  end

  def handle_event(
        "form_changed",
        %{"run_chore" => %{"chore" => chore_name} = attrs},
        %{assigns: %{chores: chores, currently_selected_chore: currently_selected_chore}} = socket
      ) do
    selected_chore = chores[chore_name]

    if(currently_selected_chore == selected_chore) do
      chore_attrs = Map.get(attrs, "chore_attrs", %{})

      errors =
        case selected_chore.validate_input(chore_attrs) do
          {:ok, _} -> []
          {:error, errors} -> errors
        end

      {:noreply, assign_errors(socket, errors)}
    else
      socket =
        socket
        |> assign(
          currently_selected_chore: selected_chore,
          form_selected_chore: chore_name,
          chore_errors: %{},
          is_chore_valid: true
        )
        |> set_inputs(selected_chore.inputs())

      {:noreply, socket}
    end
  end

  def handle_event("run_chore", %{"run_chore" => %{"chore" => chore_name} = attrs}, socket) do
    file_attrs =
      Enum.map(socket.assigns.file_inputs, fn file_input ->
        uploaded_file =
          consume_uploaded_entries(socket, file_input, fn %{path: path}, _entry ->
            tmp_dir = System.tmp_dir!()
            File.mkdir(Path.join(tmp_dir, "chore_files"))
            dest = Path.join([System.tmp_dir!(), "chore_files", Path.basename(path)])
            File.cp!(path, dest)
            dest
          end)
          |> List.first()

        {file_input, uploaded_file}
      end)
      |> Enum.into(%{})

    chore = socket.assigns.chores[chore_name]
    chore_attrs = Map.get(attrs, "chore_attrs", %{}) |> Map.merge(file_attrs)

    errors =
      case ChoreRunner.run_chore(chore, chore_attrs) do
        {:ok, _} -> []
        {:error, errors} -> errors
      end

    {:noreply, assign_errors(socket, errors)}
  end

  def handle_event(event, _attrs, socket) do
    Logger.debug("Unhandled event #{inspect(event)} in ChoreRunnerUI.ChoreLive")
    {:noreply, socket}
  end

  def handle_info({:chore_started, chore}, socket) do
    {:noreply,
     assign(
       socket,
       :running_chores,
       [chore | socket.assigns.running_chores]
     )}
  end

  def handle_info({:chore_update, chore}, socket) do
    {:noreply,
     assign(
       socket,
       :running_chores,
       update_running_chore(socket.assigns.running_chores, chore)
     )}
  end

  def handle_info({:chore_finished, chore}, socket) do
    {:noreply,
     assign(
       socket,
       :running_chores,
       remove_running_chore(socket.assigns.running_chores, chore)
     )}
  end

  def handle_info(unhandled, socket) do
    Logger.debug("Unhandled message #{inspect(unhandled)} sent to ChoreRunnerUI.ChoreLive")
    {:noreply, socket}
  end

  defp subscribe_to_pubsub(%{"pubsub" => pubsub}) do
    Phoenix.PubSub.subscribe(pubsub, ChoreRunner.chore_pubsub_topic(:all))
  end

  defp subscribe_to_pubsub(_), do: :noop

  defp list_chores(%{"otp_app" => app, "chore_root" => root}) do
    split_root = Module.split(root) |> Enum.reverse()

    {:ok, modules} = :application.get_key(app, :modules)

    modules
    |> Enum.map(fn module ->
      module
      |> Module.split()
      |> Enum.reverse()
      |> case do
        [trimmed_module | ^split_root] ->
          if(function_exported?(module, :inputs, 0)) do
            {trimmed_module, module}
          else
            nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.into(%{})
  end

  defp list_chores(_), do: []

  defp update_running_chore(running_chores, %{id: id} = chore) do
    Enum.map(running_chores, fn
      %{id: ^id, logs: logs} ->
        %{chore | logs: chore.logs ++ logs}

      chore ->
        chore
    end)
  end

  defp remove_running_chore(running_chores, %{id: id}) do
    Enum.reject(running_chores, &(&1.id == id))
  end

  defp set_inputs(socket, nil), do: socket

  defp set_inputs(socket, inputs) do
    socket
    |> disable_previous_file_inputs()
    |> assign(inputs: inputs)
    |> assign(
      :file_inputs,
      inputs |> Enum.filter(&(elem(&1, 0) == :file)) |> Enum.map(&elem(&1, 1))
    )
    |> enable_file_inputs()
  end

  defp disable_previous_file_inputs(%{assigns: %{inputs: nil}} = socket), do: socket

  defp disable_previous_file_inputs(%{assigns: %{inputs: inputs}} = socket) do
    inputs
    |> Enum.filter(fn {type, _key, _opts} -> type == :file end)
    |> Enum.reduce(socket, fn {:file, key, _opts}, socket ->
      disallow_upload(socket, key)
    end)
  end

  defp enable_file_inputs(%{assigns: %{inputs: nil}} = socket), do: socket

  defp enable_file_inputs(%{assigns: %{inputs: inputs}} = socket) do
    inputs
    |> Enum.filter(fn {type, _key, _opts} -> type == :file end)
    |> Enum.reduce(socket, fn {:file, key, _opts}, socket ->
      allow_upload(socket, key, accept: :any, max_entries: 1)
    end)
  end

  defp assign_errors(socket, []) do
    assign(socket, chore_errors: %{}, is_chore_valid: true)
  end

  defp assign_errors(socket, errors) do
    assign(socket, chore_errors: Enum.into(errors, %{}), is_chore_valid: false)
  end
end
