defmodule ChoreRunner.Server do
  use GenServer
  alias ChoreRunner.{ChoreSupervisor, Reporter}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{chores: %{}}}
  end

  @impl true
  def handle_call({:run_chore, chore_mod, input, opts}, {from, _}, state) do
    with {:ok, validated_input} <- chore_mod.validate_input(input),
         {:ok, task, ref} <- do_start_chore(chore_mod, validated_input, opts) do
      {:reply, {:ok, ref},
       put_in(state, [:chores, task.ref], %{task: task, mod: chore_mod, ref: ref, caller: from})}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list_chores, _from, state) do
    chores =
      Enum.map(state.chores, fn
        {_, %{mod: mod, ref: ref}} ->
          {mod, ref, Reporter.get_chore_state(ref)}

        _ ->
          nil
      end)
      |> Enum.reject(&is_nil/1)

    {:reply, chores, state}
  end

  @impl true
  def handle_info({task, result}, state) do
    {%{caller: caller, mod: mod}, new_state} = pop_in(state, [:chores, task])
    send(caller, {:chore_result, mod, result})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, task, _, _, reason}, state) do
    {chore_info, new_state} = pop_in(state, [:chores, task])

    unless reason == :normal or !chore_info.caller do
      send(chore_info.caller, {:chore_failed, chore_info.mod, reason})
    end

    {:noreply, new_state}
  end

  defp try_lock(:none), do: true
  defp try_lock(lock_type), do: :global.set_lock(lock_id(lock_type), all_nodes(), 0)

  defp lock_id(:global), do: {__MODULE__, self()}
  defp lock_id(chore_mod), do: {chore_mod, self()}

  defp all_nodes, do: [node() | Node.list()]

  defp do_start_chore(chore_mod, input, opts) do
    timeout = Keyword.get(opts, :lock_timeout, 1000)
    ref = make_ref()
    server = self()

    task =
      Task.Supervisor.async_nolink(ChoreSupervisor, fn ->
        do_chore_task(chore_mod, input, server, ref, opts)
      end)

    subscribers = Keyword.get(opts, :subscribers, [])

    receive do
      {:locked, ^ref} ->
        ChoreRunner.Reporter.register_task(task, chore_mod, ref, subscribers)
        send(task.pid, {:registered, ref})
        {:ok, task, ref}
    after
      timeout ->
        Task.shutdown(task, :brutal_kill)
        {:error, :already_running}
    end
  end

  defp do_chore_task(chore_mod, input, server, ref, _opts) do
    lock_arg =
      case chore_mod.restriction do
        :none -> :none
        :self -> chore_mod
        :global -> :global
      end

    if try_lock(lock_arg) do
      send(server, {:locked, ref})

      receive do
        {:registered, ^ref} -> :ok
      end

      Reporter.report_started()
      chore_mod.run(input)
      Reporter.report_finished()
    end
  end
end
