defmodule Chore.Supervisor do
  @moduledoc false

  def start_link(opts) do
    children = [
      {Task.Supervisor, name: Chore.ChoreSupervisor},
      {Chore.Reporter, opts},
      {Chore.Server, opts}
    ]

    sup_opts = [strategy: :one_for_one, name: Chore.Supervisor]
    Supervisor.start_link(children, sup_opts)
  end
end
