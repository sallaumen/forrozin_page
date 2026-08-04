defmodule OGrupoDeEstudos.Application do
  @moduledoc false

  use Application

  require Logger

  alias OGrupoDeEstudos.Admin.ErrorLogger
  alias OGrupoDeEstudos.Workers.StartupScripts

  @impl true
  def start(_type, _args) do
    children = [
      OGrupoDeEstudosWeb.Telemetry,
      OGrupoDeEstudos.Repo,
      {DNSCluster,
       query: Application.get_env(:o_grupo_de_estudos, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OGrupoDeEstudos.PubSub},
      OGrupoDeEstudosWeb.Presence,
      OGrupoDeEstudos.RateLimiter,
      {Oban, Application.fetch_env!(:o_grupo_de_estudos, Oban)},
      OGrupoDeEstudosWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: OGrupoDeEstudos.Supervisor]
    result = Supervisor.start_link(children, opts)

    if Application.get_env(:o_grupo_de_estudos, :persist_error_logs, true) do
      ErrorLogger.install()
    end

    if Application.get_env(:o_grupo_de_estudos, :env) != :test do
      enqueue_startup_scripts()
    end

    result
  end

  # Startup work runs as an Oban job (observable, with retry) instead of a bare
  # Task with sleep. Failing to enqueue must not bring the boot down.
  defp enqueue_startup_scripts do
    case StartupScripts.enqueue() do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error("StartupScripts enqueue falhou no boot", reason: inspect(reason))
        :error
    end
  end

  @impl true
  def config_change(changed, _new, removed) do
    OGrupoDeEstudosWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
