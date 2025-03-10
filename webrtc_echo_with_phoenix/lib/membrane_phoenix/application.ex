defmodule MembranePhoenix.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MembranePhoenixWeb.Telemetry,
      # MembranePhoenix.Repo,
      {DNSCluster, query: Application.get_env(:membrane_phoenix, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MembranePhoenix.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: MembranePhoenix.Finch},
      # Start a worker by calling: MembranePhoenix.Worker.start_link(arg)
      # {MembranePhoenix.Worker, arg},
      # Start to serve requests, typically the last entry
      MembranePhoenixWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MembranePhoenix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MembranePhoenixWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
