defmodule RtmpToHlsWeb.Router do
  use RtmpToHlsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RtmpToHlsWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RtmpToHlsWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/video/:filename", HlsController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", RtmpToHlsWeb do
  #   pipe_through :api
  # end
end
