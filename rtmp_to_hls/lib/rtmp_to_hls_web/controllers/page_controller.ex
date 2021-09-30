defmodule RtmpToHlsWeb.PageController do
  use RtmpToHlsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
