defmodule VideoRoom.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VideoRoomWeb.Endpoint,
      {Phoenix.PubSub, name: VideoRoom.PubSub},
      {Registry, keys: :unique, name: VideoRoom.Pipeline.registry()}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
