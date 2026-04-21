defmodule OGrupoDeEstudos.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        OGrupoDeEstudosWeb.Telemetry,
        OGrupoDeEstudos.Repo,
        {DNSCluster,
         query: Application.get_env(:o_grupo_de_estudos, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: OGrupoDeEstudos.PubSub},
        OGrupoDeEstudos.RateLimiter,
        {Oban, Application.fetch_env!(:o_grupo_de_estudos, Oban)},
        OGrupoDeEstudosWeb.Endpoint
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OGrupoDeEstudos.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Install error logger after Repo is up
    if Application.get_env(:o_grupo_de_estudos, :persist_error_logs, true) do
      OGrupoDeEstudos.Admin.ErrorLogger.install()
    end

    result
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OGrupoDeEstudosWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
