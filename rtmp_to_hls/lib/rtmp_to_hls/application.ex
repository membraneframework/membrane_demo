defmodule RtmpToHls.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias Membrane.RTMP.Source.TcpServer

  @port 9006
  @local_ip {127, 0, 0, 1}

  @impl true
  def start(_type, _args) do
    tcp_server_options = %TcpServer{
      port: @port,
      listen_options: [
        :binary,
        packet: :raw,
        active: false,
        ip: @local_ip
      ],
      socket_handler: fn socket ->
        Membrane.Demo.RtmpToHls.start_link(socket: socket)
      end
    }

    children = [
      # Start the Tcp Server
      # Membrane.Demo.RtmpToHls,
      %{
        id: TcpServer,
        start: {TcpServer, :start_link, [tcp_server_options]}
      },
      # Start the Telemetry supervisor
      RtmpToHlsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: RtmpToHls.PubSub},
      # Start the Endpoint (http/https)
      RtmpToHlsWeb.Endpoint
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
