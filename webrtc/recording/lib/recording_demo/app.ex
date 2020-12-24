defmodule Membrane.Recording.App do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.{Peer, Room}
  alias RecordingDemo.{Router, Signaling}

  @impl true
  def start(_type, _args) do
    children = [
      Plug.Cowboy.child_spec(
        scheme: :https,
        plug: Example.Simple.Router,
        options: [
          dispatch: dispatch(),
          port: 8443,
          ip: {0, 0, 0, 0},
          otp_app: :recording_demo,
          # Attach your SSL certificate and key files here
          keyfile: "priv/certs/key.pem",
          certfile: "priv/certs/certificate.pem"
        ]
      )
    ]

    opts = [strategy: :one_for_one, name: Example.Simple.Application]
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
