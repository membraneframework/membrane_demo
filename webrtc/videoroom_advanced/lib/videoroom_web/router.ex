defmodule VideoRoomWeb.Router do
  use VideoRoomWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", VideoRoomWeb do
    pipe_through(:browser)

    get("/", PageController, :index)

    post("/", PageController, :enter)

    get("/room/:room_id", RoomController, :index)

    get("/healthcheck", PageController, :healthcheck)
  end
end
