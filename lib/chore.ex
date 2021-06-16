defmodule Chore do
  @moduledoc """
  Behaviour for new Chores as well as Worker for running Chores
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
  use GenServer
  alias Chore.Input
  require Chore.Input

  defmacro __using__(_args) do
    quote do
      @behaviour Chore
      Module.register_attribute(__MODULE__, :chore_input, accumulate: true)
      import Chore, only: [input: 2]
      @before_compile {unquote(__MODULE__), :__before_compile_validate_input__}
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile_validate_input__(env) do
    for {key, type} <- Module.get_attribute(env.module, :chore_input, []) do
      quote do
        def __validate_input__(unquote(key), value) do
          case Input.validate(unquote(type), value) do
            {:ok, value} -> {:ok, {unquote(key), value}}
            {:error, reason} -> {:error, {reason, value}}
          end
        end
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def validate_input(input) do
        Enum.reduce(input, {true, []}, fn {key, val}, {valid?, errors} ->
          case __MODULE__.__validate_input__(key, val) do
            {:ok, _} ->
              {valid?, errors}

            {:error, reason} ->
              {false, [{key, reason} | errors]}
          end
        end)
        |> case do
          {true, _} -> {:ok, input}
          {false, errors} -> {:error, errors}
        end
      end

      def __validate_input__(key, _) do
        {:error, {:unexpected_key, key}}
      end

      def inputs, do: @chore_input
    end
  end

  defmacro input(key, type) when Input.valid_type(type) do
    quote do
      Module.put_attribute(__MODULE__, :chore_input, {unquote(key), unquote(type)})
    end
  end

  defmacro input(key, type) do
    """
    Input #{inspect(key)} has invalid type (#{inspect(type)}).
    Type must be one of the following valid types:
    #{Input.types() |> Enum.map(&inspect/1) |> Enum.join(", ")}
    """
    |> raise()
  end

  @callback run(map()) :: {:ok, any()} | {:error, any()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:run_chore, chore_mod, input}, _, state) do
    with {:ok, input} <- chore_mod.validate_input(input),
         true <- try_lock() do
      result = chore_mod.run(input)
      unlock()
      {:reply, result, state}
    else
      false ->
        {:reply, {:error, :other_node_running}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @spec run_chore(module(), map(), integer() | :infinity) :: {:ok, any()} | {:error, any()}
  def run_chore(chore_mod, input, timeout) do
    GenServer.call(__MODULE__, {:run_chore, chore_mod, input}, timeout)
  end

  defp try_lock, do: :global.set_lock(lock_id(), all_nodes(), 0)

  defp unlock, do: :global.del_lock(lock_id(), all_nodes())

  defp lock_id, do: {__MODULE__, self()}

  defp all_nodes, do: [node() | Node.list()]
end
