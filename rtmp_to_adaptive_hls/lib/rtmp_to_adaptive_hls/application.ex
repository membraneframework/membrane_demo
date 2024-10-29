defmodule RtmpToAdaptiveHls.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @port 9006
  @local_ip {127, 0, 0, 1}

  @impl true
  def start(_type, _args) do
    File.mkdir_p("output")

    tcp_server_options = %{
      port: @port,
      listen_options: [
        :binary,
        packet: :raw,
        active: false,
        ip: @local_ip
      ],
      handle_new_client: fn client_ref, app, stream_key ->
        {:ok, _sup, pid} =
          Membrane.Pipeline.start_link(Membrane.Demo.RtmpToAdaptiveHls, %{
            client_ref: client_ref,
            app: app,
            stream_key: stream_key
          })

        {Membrane.Demo.RtmpToAdaptiveHls.ClientHandler, %{pipeline: pid}}
      end
    }

    children = [
      # Start the RTMP server
      %{
        id: Membrane.RTMPServer,
        start: {Membrane.RTMPServer, :start_link, [tcp_server_options]}
      },
      # Start the Telemetry supervisor
      RtmpToAdaptiveHlsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: RtmpToAdaptiveHls.PubSub},
      # Start the Endpoint (http/https)
      RtmpToAdaptiveHlsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: RtmpToAdaptiveHls.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RtmpToAdaptiveHlsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
