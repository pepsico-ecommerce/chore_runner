defmodule ChoreRunner.ChoreCase.TestReporter do
  use GenServer

  def init(_) do
    {:ok, []}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def handle_cast(event, state), do: {:noreply, [event | state]}

  def handle_call({:assert_logged, enum_func}, _, state) do
    {:reply, Enum.find(state, enum_func), state}
  end

  def handle_call(:logs, _, state) do
    logs =
      state
      |> Enum.map(fn
        {:log, log, _} -> log
        _ -> nil
      end)
      |> Enum.filter(& &1)
      |> Enum.join("\n")

    {:reply, logs, state}
  end

  def handle_call(event, _, state), do: {:reply, :ok, [event | state]}

  def assert_event(pid, event) do
    GenServer.call(pid, {:assert_event, event})
  end
end
