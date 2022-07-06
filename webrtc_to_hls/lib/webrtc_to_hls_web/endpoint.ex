defmodule WebRTCToHLSWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :membrane_webrtc_to_hls_demo

  socket("/socket", WebRTCToHLSWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  plug(Plug.Static,
    at: "/",
    from: :membrane_webrtc_to_hls_demo,
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

  plug(WebRTCToHLSWeb.Router)
end
