defmodule Chore.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Chore.Supervisor]
    Supervisor.start_link([Chore], opts)
  end
end
