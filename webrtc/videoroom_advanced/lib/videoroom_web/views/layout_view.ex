defmodule VideoRoomWeb.LayoutView do
  use VideoRoomWeb, :view

  def version() do
    Application.fetch_env!(:membrane_videoroom_demo, :version)
  end
end
