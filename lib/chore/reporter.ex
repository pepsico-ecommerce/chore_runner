defmodule Chore.Reporter do
  use GenServer
  require Logger

  def init(opts) do
    :ets.new(__MODULE__, [:named_table, :set, :protected, read_concurrency: true])

    if pubsub = Keyword.get(opts, :pubsub) do
      :persistent_term.put({__MODULE__, :pubsub}, pubsub)
    else
      Logger.warn(
        "Chore was started without the `:pubsub` option, chore reporting via pubsub is disabled. This will prevent `ChoreUI` from functioning properly"
      )
    end

    {:ok, %{}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_task(task, chore_mod, ref, pids \\ [], pubsub_topics \\ []) do
    GenServer.call(__MODULE__, {:register_task, task, ref, chore_mod, pids, pubsub_topics})
  end

  def get_chore_state(ref) do
    ms = [{{:_, :"$1", :_, :_, :_, :"$2"}, [{:==, :"$1", ref}], [:"$2"]}]

    :ets.select(__MODULE__, ms)
    |> List.first()
  end

  def handle_call(
        {:register_task, %Task{pid: pid}, ref, chore_mod, pids, pubsub_topics},
        _,
        state
      ) do
    reported_state = %Chore{logs: [], percent: 0, scalar: 0}
    :ets.insert(__MODULE__, {pid, ref, chore_mod, pids, pubsub_topics, reported_state})
    {:reply, :ok, state}
  end

  def handle_cast({:update_state, pid, type, value}, state) do
    :ets.lookup_element(__MODULE__, pid, 6)
    |> build_new_state(type, value)
    |> do_update_state(pid)

    {:noreply, state}
  rescue
    ArgumentError ->
      {:noreply, state}
  end

  defp build_new_state(state, :log, value), do: %Chore{state | logs: [value | state.logs]}
  defp build_new_state(state, type, value), do: Map.put(state, type, value)

  defp do_update_state(new_state, pid), do: :ets.update_element(__MODULE__, pid, {6, new_state})

  def report_started do
    report_status(:chore_started)
  end

  def report_finished do
    report_status(:chore_finished)
  end

  defp report_status(status) do
    case :ets.lookup(__MODULE__, self()) do
      [{_, ref, mod, pids, pubsub_topics, _state}] ->
        do_send_reports({status, mod, ref}, pids, pubsub_topics)

      [] ->
        report_error()
    end
  end

  def report_percent(percent) do
    do_report(:percent, percent)
  end

  def report_scalar(scalar) do
    do_report(:scalar, scalar)
  end

  def log(message) do
    do_report(:log, {DateTime.utc_now(), message})
  end

  defp do_report(type, value) do
    case :ets.lookup(__MODULE__, self()) do
      [{pid, ref, mod, pids, pubsub_topics, _state}] ->
        if type == :log, do: Logger.info(" [Chore] [#{mod}] #{elem(value, 1)}")
        update_state(pid, type, value)
        do_send_reports(build_report(type, mod, ref, value), pids, pubsub_topics)

      [] ->
        report_error()
    end
  end

  defp update_state(pid, type, value) do
    GenServer.cast(__MODULE__, {:update_state, pid, type, value})
  end

  defp do_send_reports(report, pids, pubsub_topics) do
    Enum.each(pids, fn pid ->
      send(pid, report)
    end)

    if pubsub = :persistent_term.get({__MODULE__, :pubsub}, nil) do
      Enum.each(pubsub_topics, fn topic ->
        Phoenix.PubSub.broadcast(pubsub, topic, report)
      end)

      Phoenix.PubSub.broadcast(pubsub, ChoreUI.pubsub_topic(), report)
    end
  end

  defp build_report(:log, mod, ref, message) do
    {:chore_log, mod, ref, message}
  end

  defp build_report(type, mod, ref, value) do
    {:chore_progress, mod, ref, {type, value}}
  end

  defp report_error do
    raise """
    All chore reporting functions must be called from inside a currently running chore
    """
  end
end
