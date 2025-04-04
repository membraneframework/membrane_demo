defmodule WebrtcLiveView.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WebrtcLiveViewWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:webrtc_live_view, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WebrtcLiveView.PubSub},
      # Start a worker by calling: WebrtcLiveView.Worker.start_link(arg)
      # {WebrtcLiveView.Worker, arg},
      # Start to serve requests, typically the last entry
      WebrtcLiveViewWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WebrtcLiveView.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WebrtcLiveViewWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
