defmodule Membrane.Demo.WebRTCToHLS.Router do
  use Plug.Router

  plug(Plug.Static,
    at: "/",
    from: :membrane_webrtc_to_hls_demo
  )

  plug(:match)
  plug(:dispatch)

  get "/video/:user/:file" do
    path = "output/#{user}/#{file}"
    if File.exists?(path) do
      send_file(conn, 200, path)
    else
      send_resp(conn, 404, "File not found")
    end
  end

  get "/" do
    send_file(conn, 200, "priv/static/html/index.html")
  end


  match _ do
    send_resp(conn, 404, "404")
  end
end
