defmodule RtmpToAdaptiveHlsWeb.PageController do
  use RtmpToAdaptiveHlsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
