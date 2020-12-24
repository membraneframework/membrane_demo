defmodule Membrane.Recording.App do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.{Peer, Room}
  alias RecordingDemo.{Router, Signaling}

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:recording_demo) |> Map.new()

    children = [
      Plug.Cowboy.child_spec(
        scheme: :https,
        # FIXME: Routers leak - they're spawned on each "/" request and are not terminated
        # can be seen in observer
        plug: Router,
        options: [
          dispatch: dispatch(),
          port: config.port,
          ip: config.ip,
          otp_app: :recording_demo,
          # Attach your SSL certificate and key files here
          keyfile: config.keyfile,
          certfile: config.certfile
        ]
      )
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/record", Peer, %Peer.Options{module: Signaling.JSPeer}},
         {"/membrane/[:room]", Membrane.WebRTC.Server.Peer,
          %Peer.Options{module: Signaling.MembranePeer}},
         {:_, Plug.Cowboy.Handler, {Router, []}}
       ]}
    ]
  end
end
