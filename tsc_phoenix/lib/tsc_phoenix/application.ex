defmodule TscPhoenix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Initialize ETS tables for dependency graph
    TSC.Graph.DependencyGraph.init()

    children = [
      TscPhoenixWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:tsc_phoenix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TscPhoenix.PubSub},

      # Compiler core services
      TSC.Cache.TypeCache,
      TSC.Cache.FileCache,
      TSC.Telemetry.Reporter,
      {TSC.Worker.PoolSupervisor, pool_size: pool_size()},
      TSC.Watcher.FileWatcher,

      # Start to serve requests, typically the last entry
      TscPhoenixWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TscPhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp pool_size do
    Application.get_env(:tsc_phoenix, :worker_pool_size, System.schedulers_online())
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TscPhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
