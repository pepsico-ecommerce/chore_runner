defmodule ChoreRunner.Supervisor do
  @moduledoc false

  def start_link(opts) do
    children = [
      {Task.Supervisor, name: ChoreRunner.ChoreSupervisor},
      {ChoreRunner.Reporter, opts},
      {ChoreRunner.Server, opts}
    ]

    sup_opts = [strategy: :one_for_one, name: ChoreRunner.Supervisor]
    Supervisor.start_link(children, sup_opts)
  end
end
