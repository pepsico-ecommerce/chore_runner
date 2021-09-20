defmodule ChoreRunner do
  @moduledoc """
  Runs Chores
  Example of writing a Chore:
  ```elixir
  defmodule MyApp.MyChore do
    use ChoreRunner.Chore

    input :my_file, :file

    def run(%{my_file: %Plug.Upload{path: path}}) do
      path
      |> File.read!()
      |> parse_file()
      |> do_stuff()
    end
  end
  ```
  Example of running this ChoreRunner:
  ```
  iex> ChoreRunner.run_chore(MyApp.MyChore, %{my_file: file}, :infinity)
  {:ok, ...}
  ```
  """
  alias ChoreRunner.{Chore, ReporterSupervisor, Reporter}

  @doc false
  def child_spec(opts) do
    %{
      id: ChoreRunner.Supervisor,
      start: {ChoreRunner.Supervisor, :start_link, [opts]}
    }
  end

  @spec list_running_chores() :: [Chore.t()]
  def list_running_chores do
    __MODULE__
    |> :pg.get_members(Reporter)
    |> Task.async_stream(fn pid -> GenServer.call(pid, :chore_state) end)
    |> Enum.flat_map(fn
      {:ok, chore} -> [chore]
      _ -> []
    end)
  end

  @spec chore_pubsub_topic(Chore.t() | :all) :: String.t()
  def chore_pubsub_topic(:all), do: "chore_runner:*"

  def chore_pubsub_topic(%Chore{id: id}) do
    "chore_runner:id-#{id}"
  end

  @spec run_chore(module(), map(), Keyword.t()) :: {:ok, reference()} | {:error, any()}
  def run_chore(chore_mod, input, opts \\ []) do
    chore = %Chore{mod: chore_mod, id: gen_id()}

    with {:ok, validated_input} <- Chore.validate_input(chore, input),
         {:ok, updated_chore = %Chore{reporter: pid}} when not is_nil(pid) <-
           do_start_reporter(chore, opts),
         {:ok, started_chore} <- do_start_chore(updated_chore, validated_input, opts) do
      {:ok, started_chore}
    end
  end

  defp gen_id do
    16
    |> :crypto.strong_rand_bytes()
    |> Base.encode16()
  end

  defp do_start_reporter(%Chore{} = chore, opts) do
    with {:ok, pid} <-
           DynamicSupervisor.start_child(
             ReporterSupervisor,
             {Reporter, Keyword.put(opts, :chore, chore)}
           ),
         :ok <- :pg.join(ChoreRunner, Reporter, pid) do
      {:ok, %Chore{chore | reporter: pid}}
    end
  end

  defp do_start_chore(%Chore{reporter: reporter_pid}, input, opts) do
    # Start the task from the reporter so that the task reports to the reporter server

    {:ok, GenServer.call(reporter_pid, {:start_chore_task, input, opts})}
  end
end
