defmodule ChoreRunner.Supervisor do
  @moduledoc false

  def start_link(opts) do
    children = [
      %{id: :pg, start: {:pg, :start_link, [ChoreRunner]}},
      {Task.Supervisor, name: ChoreRunner.ChoreSupervisor},
      {ChoreRunner.ReporterSupervisor, [opts]}
    ]

    sup_opts = [strategy: :one_for_one, name: ChoreRunner.Supervisor]
    Supervisor.start_link(children, sup_opts)
  end
end
