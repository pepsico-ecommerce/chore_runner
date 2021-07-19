defmodule Chore do
  @moduledoc """
  Behaviour for new Chores as well as an api for running Chores
  Example of writing a Chore:
  ```elixir
  defmodule MyApp.MyChore do
    use Chore

    input :my_file, :file

    def run(%{my_file: %Plug.Upload{path: path}}) do
      path
      |> File.read!()
      |> parse_file()
      |> do_stuff()
    end
  end
  ```
  Example of running this Chore:
  ```
  iex> Chore.run_chore(MyApp.MyChore, %{my_file: file}, :infinity)
  {:ok, ...}
  ```
  """
  require Chore.DSL
  alias Chore.{Server, DSL}

  defstruct logs: [], percent: 0, scalar: 0

  defmacro __using__(_args), do: DSL.using()

  @callback restriction :: :none | :self | :global
  @callback run(map()) :: {:ok, any()} | {:error, any()}

  @type unix_timestamp :: integer()
  @type t :: %__MODULE__{
          logs: [{unix_timestamp, String.t()}],
          percent: integer(),
          scalar: integer()
        }

  @doc false
  def child_spec(opts) do
    %{
      id: Chore.Supervisor,
      start: {Chore.Supervisor, :start_link, [opts]}
    }
  end

  @spec list_running_chores() :: [t()]
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
