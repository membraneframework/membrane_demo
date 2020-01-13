defmodule Example.Simple.Application do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.Peer
  alias Membrane.WebRTC.Server.Room

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
          password: "PASSWORD",
          otp_app: :example_simple,
          # Attach your SSL certificate and key files here
          keyfile: "priv/certs/key.pem",
          certfile: "priv/certs/certificate.pem"
        ]
      ),
      Supervisor.child_spec(
        {Room,
         %Room.Options{
           name: "room",
           module: Example.Simple.Room,
           custom_options: %{max_peers: 2}
         }},
        id: :room
      ),
      Supervisor.child_spec(
        {Room,
         %Room.Options{
           name: "other",
           module: Example.Simple.Room,
           custom_options: %{max_peers: 2}
         }},
        id: :other_room
      )
    ]

    opts = [strategy: :one_for_one, name: Example.Simple.Application]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    options = %Peer.Options{module: Example.Simple.Peer}

    [
      {:_,
       [
         {"/webrtc/[:room]/", Membrane.WebRTC.Server.Peer, options},
         {:_, Plug.Cowboy.Handler, {Example.Simple.Router, []}}
       ]}
    ]
  end
end
