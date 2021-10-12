defmodule ChoreRunner do
  @moduledoc """
  A framework and library for productively writing and running "code chores".
  A "Code Chore" can really be anything,
  but most commonly is some infrequently,
  manually run code that affects production to achieve a business goal.
  For example: updating a config value in a database that does not yet have a UI (perhaps due to time constraints) is a great use for a chore.
  A chore could be created that accepts the desired value and runs the update query.
  Usually, the alternative to this would be a direct prod-shell or prod-db connection, which is inherently insecure and dangerous.
  Many fast-moving startups or companies are ok with this access for developers, and that's fine.
  But many companies have regulations that they must follow, or do not want to take the risk of a developer mistake while working in these environments.
  In these cases, ChoreRunner allows the rapid creation, testing, and reviewing of code chores, along with a bundled UI for running them that accepts a variety of input types,
  with the goal of finding a "sweet spot" of safety and speed when solving such problems.
  ## Getting Started
  Add `ChoreRunner` to your supervision tree, after your app's `PubSub`:
  ```
  children = [
    {Phoenix.PubSub, [name: MyApp.PubSub]},
    {ChoreRunner, [pubsub: MyApp.PubSub]},
  ]
  ```
  ## Writing a chore
  ```
  defmodule MyApp.MyChore do
    use ChoreRunner.Chore

    input :my_file, :file

    def run(%{my_file: path}}) do
      path
      |> File.read!()
      |> parse_file()
      |> do_stuff()
    end
  end
  ```
  Example of running this Chore:
  ```
  iex> ChoreRunner.run_chore(MyApp.MyChore, %{my_file: file}, :infinity)
  {:ok, %Chore{}}
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

  @doc """
  List the currently running chores on all nodes.
  """
  @spec list_running_chores() :: [Chore.t()]
  def list_running_chores do
    __MODULE__
    |> :pg.get_members(Reporter)
    |> Enum.map(&:gen_server.send_request(&1, :chore_state))
    |> Enum.flat_map(fn request ->
      case :gen_server.receive_response(request, 1000) do
        {:reply, chore} -> [chore]
        :timeout -> []
        {:error, _reason} -> []
      end
    end)
  end

  @doc """
  Returns the pubsub topic used for a specific chore, or all chores if given the atom `:all`
  """
  @spec chore_pubsub_topic(Chore.t() | :all) :: String.t()
  def chore_pubsub_topic(:all), do: "chore_runner:*"

  def chore_pubsub_topic(%Chore{id: id}) do
    "chore_runner:id-#{id}"
  end

  @doc """
  Runs the given chore module as a chore.
  Accepts an input map with either string or atom keys as well as a keyword list of options.
  Returns a `%ChoreRunner.Chore{}` struct.

  Input map keys must match one of the inputs defined in the provided chore module.
  If not, the input under the unmatched key is discarded.
  Matched input will have default validations run on them, as well custom validations declared in the chore module.
  If any inputs fail validation, the chore will not run, and instead an error tuple will be returned.
  If all validations pass, the chore will then be run.

  Currently, no options are supported.

  """
  @spec run_chore(module(), map(), Keyword.t()) :: {:ok, Chore.t()} | {:error, any()}
  def run_chore(chore_mod, input, opts \\ []) do
    chore = %Chore{mod: chore_mod, id: gen_id()}

    with {:ok, validated_input} <- Chore.validate_input(chore, input),
         {:ok, updated_chore = %Chore{reporter: pid}} when not is_nil(pid) <-
           do_start_reporter(chore, opts),
         {:ok, started_chore} <- do_start_chore(updated_chore, validated_input, opts) do
      {:ok, started_chore}
    end
  end

  @doc """
  Stops the provided chore by terminating both the chore task and the reporter.
  Returns `:ok` if successful, and `:error` if not successful
  """
  @spec stop_chore(Chore.t()) :: :ok | :error
  def stop_chore(%Chore{reporter: pid} = chore) do
    GenServer.call(pid, :stop_chore)
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
