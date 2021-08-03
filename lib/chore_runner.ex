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
  alias ChoreRunner.{Server, Chore}

  @doc false
  def child_spec(opts) do
    %{
      id: ChoreRunner.Supervisor,
      start: {ChoreRunner.Supervisor, :start_link, [opts]}
    }
  end

  @spec list_running_chores() :: [Chore.t()]
  def list_running_chores do
    {replies, _} = GenServer.multi_call(Server, :list_chores)
    Enum.flat_map(replies, fn {_, chores} -> chores end)
  end

  @spec run_chore(module(), map(), Keyword.t()) :: {:ok, reference()} | {:error, any()}
  def run_chore(chore_mod, input, opts \\ []) do
    GenServer.call(
      Server,
      {:run_chore, chore_mod, input, opts},
      Keyword.get(opts, :call_timeout, 2000)
    )
  end
end
