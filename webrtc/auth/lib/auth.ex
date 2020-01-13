defmodule Example.Auth.Application do
  @moduledoc false
  use Application
  alias Membrane.WebRTC.Server.Peer.Options
  alias Membrane.WebRTC.Server.Room

  @impl true
  def start(_type, _args) do
    children = [
      Example.Auth.Repo,
      Plug.Cowboy.child_spec(
        scheme: Application.fetch_env!(:example_auth, :scheme),
        plug: Example.Auth.Router,
        options: [
          dispatch: dispatch(),
          port: Application.fetch_env!(:example_auth, :port),
          ip: Application.fetch_env!(:example_auth, :ip),
          password: Application.fetch_env!(:example_auth, :password),
          otp_app: :example_auth,
          keyfile: Application.fetch_env!(:example_auth, :keyfile),
          certfile: Application.fetch_env!(:example_auth, :certfile)
        ]
      ),
      Room.child_spec(%Room.Options{
        name: "room",
        module: Example.Auth.Room
      })
    ]

    options = [strategy: :one_for_one, name: Example.Auth.Application]
    Supervisor.start_link(children, options)
  end

  defp dispatch do
    options = %Options{module: Example.Auth.Peer}

    [
      {:_,
       [
         {"/webrtc/", Membrane.WebRTC.Server.Peer, options},
         {:_, Plug.Cowboy.Handler, {Example.Auth.Router, []}}
       ]}
    ]
  end
end
