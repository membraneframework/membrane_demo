defmodule VideoRoomWeb.PageController do
  use VideoRoomWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def healthcheck(conn, _params) do
    conn
    |> send_resp(200, "")
  end
end
