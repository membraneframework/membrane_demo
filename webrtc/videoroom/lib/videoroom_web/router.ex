defmodule VideoRoomWeb.Router do
  use VideoRoomWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])

    # plug :protect_from_forgery
    # plug :put_secure_browser_headers
  end

  # scope "/" do
  #   pipe_through :browser

  #   forward "/" do
  #     send_file(conn, 200, "priv/static/html/index.html")
  #   end

  #   match _ do
  #     send_resp(conn, 404, "404")
  #   end
  # end
  scope "/", VideoRoomWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)
  end
end
