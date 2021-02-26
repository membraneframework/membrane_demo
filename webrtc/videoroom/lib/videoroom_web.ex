defmodule VideoRoomWeb do
  def controller do
    quote do
      use Phoenix.Controller, namespace: VideoRoomWeb
      import Plug.Conn
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/videoroom_web/templates",
        pattern: "**/*",
        namespace: VideoRoomWeb

      # Import convenience functions from controllers
      # import Phoenix.Controller, only: [get_flash: 2, view_module: 1]
      import VideoRoomWeb.Router.Helpers

      use Phoenix.HTML
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
