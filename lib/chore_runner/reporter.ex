defmodule ChoreRunner.Reporter do
  use GenServer
  require Logger
  alias ChoreRunner.{Chore, ChoreSupervisor}

  @process_dict_key :chore_reporter_pid
  def __process_dict_key__, do: @process_dict_key

  def init({opts, chore}) do
    pubsub = Keyword.get(opts, :pubsub)
    finished_function = Keyword.get(opts, :result_handler, & &1)

    unless pubsub do
      Logger.warn(":pubsub option not supplied to `ChoreRunner.Reporter`")
    end

    send(self(), :broadcast)

    {:ok,
     %{
       chore: Map.put(chore, :reporter, self()),
       last_sent_chore: chore,
       pubsub: pubsub,
       finished_function: finished_function
     }}
  end

  def start_link(init_opts, opts) do
    merged_opts = Keyword.merge(init_opts, opts)
    chore = Keyword.fetch!(merged_opts, :chore)
    GenServer.start_link(__MODULE__, {merged_opts, chore}, name: name(chore))
  end

  defp report_started,
    do: GenServer.cast(get_reporter_pid(), {:chore_started, DateTime.utc_now()})

  defp report_finished,
    do: GenServer.cast(get_reporter_pid(), {:chore_finished, DateTime.utc_now()})

  def report_failed(reason),
    do: GenServer.cast(get_reporter_pid(), {:chore_failed, reason, DateTime.utc_now()})

  def log(message, opts \\ %{html: false, timestamp: true}),
    do: GenServer.cast(get_reporter_pid(), {:log, message, DateTime.utc_now(), opts})

  def set_counter(name, value), do: do_update_counter(name, value, :set)
  def inc_counter(name, amount), do: do_update_counter(name, amount, :inc)

  defp do_update_counter(name, value, operation),
    do: GenServer.cast(get_reporter_pid(), {:update_counter, name, value, operation})

  def get_chore_state(%Chore{} = chore) do
    GenServer.call(name(chore), :chore_state)
  end

  def handle_call(:chore_state, _from, %{chore: chore} = state), do: {:reply, chore, state}

  def handle_call(
        {:start_chore_task, input, _opts},
        _from,
        %{chore: %Chore{mod: chore_mod, task: nil} = chore} = state
      ) do
    reporter_pid = self()

    task =
      Task.Supervisor.async_nolink(ChoreSupervisor, fn ->
        put_reporter_pid_in_process(reporter_pid)

        lock_arg =
          case chore_mod.restriction do
            :none -> :none
            :self -> chore_mod
            :global -> :global
          end

        if try_lock(lock_arg) do
          report_started()
          chore_mod.run(input)
          report_finished()
        else
          report_failed("Failed to acquire lock")
        end
      end)

    new_chore = %Chore{chore | task: task}
    {:reply, new_chore, %{state | chore: new_chore}}
  end

  def handle_call(:stop_chore, _from, state) do
    ChoreSupervisor
    |> Task.Supervisor.terminate_child(state.chore.task.pid)
    |> case do
      :ok ->
        new_state =
          %{state | chore: put_log(state.chore, "Stopping Chore", DateTime.utc_now())}
          |> fail_chore("Stopped", DateTime.utc_now())

        state.finished_function.(new_state.chore)

        Task.async(fn ->
          Process.sleep(10)
          DynamicSupervisor.terminate_child(ChoreRunner.ReporterSupervisor, self())
        end)

        {:reply, :ok, new_state}

      _ ->
        {:reply, :error, state}
    end
  end

  def handle_cast({:chore_started, timestamp}, state) do
    new_state = put_in(state.chore.started_at, timestamp)
    broadcast(new_state.pubsub, new_state.chore, :chore_started)
    {:noreply, new_state}
  end

  def handle_cast({:chore_finished, timestamp}, state) do
    new_state = put_in(state.chore.finished_at, timestamp)
    broadcast(new_state.pubsub, new_state.chore, :chore_finished)
    state.finished_function.(state.chore)

    {:noreply, new_state}
  end

  def handle_cast({:chore_failed, reason, timestamp}, state) do
    new_state = fail_chore(state, reason, timestamp)
    {:noreply, new_state}
  end

  def handle_cast({:log, message, timestamp, opts}, state) do
    {:noreply, %{state | chore: put_log(state.chore, message, timestamp, opts)}}
  end

  def handle_cast({:update_counter, name, value, operation}, state) when is_number(value),
    do: {:noreply, update_in(state.chore.values[name], &do_update_values(&1, value, operation))}

  defp fail_chore(state, reason, timestamp) do
    new_state = put_in(state.chore.finished_at, timestamp)

    new_state = %{
      new_state
      | chore: put_log(new_state.chore, "Failed with reason: #{reason}", timestamp)
    }

    broadcast(new_state.pubsub, new_state.chore, :chore_failed)
    new_state
  end

  def handle_info(:broadcast, %{pubsub: nil} = state), do: {:noreply, state}

  def handle_info(:broadcast, %{chore: %{finished_at: finished_at}} = state)
      when not is_nil(finished_at),
      do: {:noreply, state}

  def handle_info(:broadcast, %{chore: chore, last_sent_chore: last_sent_chore} = state) do
    Process.send_after(self(), :broadcast, 10)

    if chore == last_sent_chore do
      {:noreply, state}
    else
      broadcast(state.pubsub, diff_chore(last_sent_chore, chore), :chore_update)

      {:noreply, %{state | last_sent_chore: chore}}
    end
  end

  def handle_info({ref, result}, %{chore: %{task: %{ref: ref}}} = state),
    do: {:noreply, put_in(state.chore.result, result)}

  def handle_info({:DOWN, ref, _, _, {error, trace}}, %{chore: %{task: %{ref: ref}}} = state) do
    {:stop, :normal,
     fail_chore(
       state,
       "Failed due to error:\n#{inspect(error)}\n#{inspect(trace)}",
       DateTime.utc_now()
     )}
  end

  def handle_info({:DOWN, ref, _, _, _}, %{chore: %{task: %{ref: ref}}} = state),
    do: {:stop, :normal, state}

  defp diff_chore(prev, current) do
    %Chore{current | logs: current.logs -- prev.logs}
  end

  defp do_update_values(nil, value, operation), do: do_update_values(0, value, operation)
  defp do_update_values(original, value, :inc), do: original + value
  defp do_update_values(_original, value, :set), do: value

  defp put_log(
         %Chore{logs: logs} = chore,
         log,
         timestamp,
         opts \\ %{html: false, timestamp: true}
       ),
       do: %Chore{chore | logs: [{log, timestamp, opts} | logs]}

  defp put_reporter_pid_in_process(reporter_pid), do: Process.put(@process_dict_key, reporter_pid)

  defp get_reporter_pid do
    case Process.get(@process_dict_key) do
      nil ->
        :"$callers"
        |> Process.get()
        |> Enum.find(fn pid ->
          Process.info(pid, :dictionary)[@process_dict_key]
        end)
        |> case do
          nil -> raise "Attempted to call a chore reporting function outside of a chore"
          pid -> pid
        end

      pid ->
        pid
    end
  end

  defp try_lock(:none), do: true
  defp try_lock(lock_type), do: :global.set_lock(lock_id(lock_type), all_nodes(), 0)

  defp lock_id(:global), do: {__MODULE__, self()}
  defp lock_id(chore_mod), do: {chore_mod, self()}

  defp all_nodes, do: [node() | Node.list()]

  defp name(%Chore{id: id}), do: {:global, {__MODULE__, id}}

  defp broadcast(nil, _, _), do: :noop

  defp broadcast(pubsub, chore, key) do
    Phoenix.PubSub.broadcast(
      pubsub,
      ChoreRunner.chore_pubsub_topic(:all),
      {key, chore}
    )

    Phoenix.PubSub.broadcast(
      pubsub,
      ChoreRunner.chore_pubsub_topic(chore),
      {key, chore}
    )
  end
end
