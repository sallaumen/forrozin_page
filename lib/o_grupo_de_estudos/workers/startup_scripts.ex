defmodule OGrupoDeEstudos.Workers.StartupScripts do
  @moduledoc """
  Runs the startup scripts (`StartupScripts.Runner`) as an Oban job.

  It replaces the bare Task with `Process.sleep/1` at boot: the job only runs with
  Repo and Oban ready, stays observable in the jobs table and has retry. The
  idempotency of each script stays in the Runner ledger (`data_migrations`); the
  short uniqueness only debounces simultaneous boots of multiple nodes.
  """

  use Oban.Worker,
    queue: :maintenance,
    max_attempts: 3,
    unique: [period: 60, states: [:available, :scheduled, :executing]]

  alias OGrupoDeEstudos.StartupScripts.Runner

  @doc "Enqueues the startup scripts run (called once at application boot)."
  def enqueue do
    %{}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Runner.run_all()
    :ok
  end
end
