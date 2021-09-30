defmodule RtmpToHls.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      RtmpToHlsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: RtmpToHls.PubSub},
      # Start the Endpoint (http/https)
      RtmpToHlsWeb.Endpoint,
      # Start the Pipeline
      # Membrane.Demo.RtmpToHls
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RtmpToHls.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RtmpToHlsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
