defmodule VideoRoomWeb.RoomController do
  use VideoRoomWeb, :controller

  def index(conn, %{"room_id" => id}) do
    render(conn, "index.html", room_id: id)
  end
end
