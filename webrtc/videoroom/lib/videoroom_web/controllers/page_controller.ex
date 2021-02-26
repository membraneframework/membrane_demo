defmodule VideoRoomWeb.PageController do
  use VideoRoomWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
