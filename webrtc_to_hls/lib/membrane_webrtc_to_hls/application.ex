defmodule Membrane.Demo.WebRTCToHLS.Application do
  @moduledoc false
  use Application

  alias Membrane.Demo.WebRTCToHLS

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:membrane_webrtc_to_hls_demo) |> Map.new()

    children = [
      Plug.Cowboy.child_spec(
        scheme: :https,
        # FIXME: Routers leak - they're spawned on each "/" request and are not terminated
        # can be seen in observer
        plug: WebRTCToHLS.Router,
        options: [
          dispatch: dispatch(),
          port: config.port,
          ip: config.ip,
          otp_app: :membrane_webrtc_to_hls_demo,
          # Attach your SSL certificate and key files here
          keyfile: config.keyfile,
          certfile: config.certfile
        ]
      ),
      {Registry, keys: :unique, name: WebRTCToHLS.Pipeline.registry()}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws", WebRTCToHLS.WS, []},
         {:_, Plug.Cowboy.Handler, {WebRTCToHLS.Router, []}}
       ]}
    ]
  end
end
