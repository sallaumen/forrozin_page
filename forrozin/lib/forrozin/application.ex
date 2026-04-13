defmodule Forrozin.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        ForrozinWeb.Telemetry,
        Forrozin.Repo,
        {DNSCluster, query: Application.get_env(:forrozin, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Forrozin.PubSub},
        {Oban, Application.fetch_env!(:forrozin, Oban)},
        ForrozinWeb.Endpoint
      ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Forrozin.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ForrozinWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
