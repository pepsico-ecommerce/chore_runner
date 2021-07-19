defmodule ChoreUI.ChoreLive do
  use ChoreUI, :live
  alias ChoreUI.ChoreView

  def mount(params, session, socket) do
    subscribe_to_pubsub(session)

    socket =
      assign(socket,
        chores: list_chores(session),
        running_chores: list_running_chores(),
        params: params,
        session: session
      )

    {:ok, socket}
  end

  def render(assigns) do
    ChoreView.render("index.html", assigns)
  end

  def handle_info({:chore_started, mod, ref}, socket) do
    chore = %{
      mod: mod,
      ref: ref,
      state: Chore.Reporter.get_chore_state(ref)
    }

    {:noreply,
     assign(
       socket,
       :running_chores,
       [chore | socket.assigns.running_chores]
     )}
  end

  def handle_info({:chore_progress, _, ref, {key, val}}, socket) do
    {:noreply,
     assign(
       socket,
       :running_chores,
       update_running_chore(socket.assigns.running_chores, ref, key, val)
     )}
  end

  def handle_info({:chore_log, _, ref, log}, socket) do
    {:noreply,
     assign(
       socket,
       :running_chores,
       update_running_chore(socket.assigns.running_chores, ref, :logs, log)
     )}
  end

  def handle_info({:chore_finished, _, ref}, socket) do
    {:noreply,
     assign(
       socket,
       :running_chores,
       remove_running_chore(socket.assigns.running_chores, ref)
     )}
  end

  def handle_info(unhandled, socket) do
    IO.inspect(unhandled, label: :unhandled)
    {:noreply, socket}
  end

  defp subscribe_to_pubsub(%{"pubsub" => pubsub}) do
    Phoenix.PubSub.subscribe(pubsub, ChoreUI.pubsub_topic())
  end

  defp subscribe_to_pubsub(_), do: :noop

  defp list_chores(%{"otp_app" => app, "chore_root" => root}) do
    split_root = Module.split(root) |> Enum.reverse()

    {:ok, modules} = :application.get_key(app, :modules)

    Enum.filter(modules, fn module ->
      module
      |> Module.split()
      |> Enum.reverse()
      |> case do
        [_ | ^split_root] -> true
        _ -> false
      end
    end)
  end

  defp list_chores(_), do: []

  defp list_running_chores do
    Chore.list_running_chores()
    |> Enum.map(fn {mod, ref, state} ->
      %{mod: mod, ref: ref, state: state}
    end)
  end

  defp update_running_chore(running_chores, ref, :logs, val) do
    Enum.map(running_chores, fn
      %{ref: ^ref, state: state} = chore ->
        %{chore | state: Map.put(state, :logs, [val | state.logs])}

      chore ->
        chore
    end)
  end

  defp update_running_chore(running_chores, ref, key, val) do
    Enum.map(running_chores, fn
      %{ref: ^ref, state: state} = chore ->
        %{chore | state: Map.put(state, key, val)}

      chore ->
        chore
    end)
  end

  defp remove_running_chore(running_chores, ref) do
    Enum.reject(running_chores, &(&1.ref == ref))
  end
end
