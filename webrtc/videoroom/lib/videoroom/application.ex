defmodule VideoRoom.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    # config = Application.get_all_env(:membrane_videoroom_demo) |> Map.new()

    children = [
      VideoRoomWeb.Endpoint,
      {Phoenix.PubSub, name: VideoRoom.PubSub},
      # Plug.Cowboy.child_spec(
      #   scheme: :https,
      #   # FIXME: Routers leak - they're spawned on each "/" request and are not terminated
      #   # can be seen in observer
      #   plug: VideoRoom.Router,
      #   options: [
      #     dispatch: dispatch(),
      #     port: config.port,
      #     ip: config.ip,
      #     otp_app: :membrane_videoroom_demo,
      #     # Attach your SSL certificate and key files here
      #     keyfile: config.keyfile,
      #     certfile: config.certfile
      #   ]
      # ),
      %{id: VideoRoom.Pipeline, start: {VideoRoom.Pipeline, :start_link, []}}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  defp dispatch do
    [
      {:_,
       [
         {"/ws", VideoRoom.WS, []},
         {:_, Plug.Cowboy.Handler, {VideoRoom.Router, []}}
       ]}
    ]
  end
end
