defmodule RiakDashboard.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RiakDashboardWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:riak_dashboard, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: RiakDashboard.PubSub},
      # Start a worker by calling: RiakDashboard.Worker.start_link(arg)
      # {RiakDashboard.Worker, arg},
      # Start to serve requests, typically the last entry
      RiakDashboardWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RiakDashboard.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RiakDashboardWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
