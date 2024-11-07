defmodule RtmpToAdaptiveHlsWeb.Router do
  use RtmpToAdaptiveHlsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {RtmpToAdaptiveHlsWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RtmpToAdaptiveHlsWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/video/:filename", HlsController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", RtmpToAdaptiveHlsWeb do
  #   pipe_through :api
  # end
end
