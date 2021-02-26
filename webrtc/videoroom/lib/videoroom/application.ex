defmodule VideoRoom.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      VideoRoomWeb.Endpoint,
      {Phoenix.PubSub, name: VideoRoom.PubSub},
      %{id: VideoRoom.Pipeline, start: {VideoRoom.Pipeline, :start_link, []}}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end
end
