defmodule VideoRoomWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :membrane_videoroom_demo

  socket("/socket", VideoRoomWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  plug(Plug.Static,
    at: "/",
    from: :membrane_videoroom_demo,
    brotli: true,
    gzip: true,
    only: ~w(assets images html svg robots.txt favicon.ico)
  )

  if code_reloading? do
    socket("/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket)
    plug(Phoenix.LiveReloader)
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Parsers,
    parsers: [
      :urlencoded,
      :multipart,
      :json,
      Absinthe.Plug.Parser
    ],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(VideoRoomWeb.Router)
end
