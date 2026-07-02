defmodule OGrupoDeEstudos.Workers.StartupScripts do
  @moduledoc """
  Runs the startup scripts (`StartupScripts.Runner`) as an Oban job.

  Substitui a Task solta com `Process.sleep/1` no boot: o job só executa
  com Repo e Oban prontos, fica observável na tabela de jobs e tem retry.
  A idempotência de cada script continua no ledger do Runner
  (`data_migrations`); a unicidade curta só debounce boots simultâneos
  de múltiplos nós.
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
