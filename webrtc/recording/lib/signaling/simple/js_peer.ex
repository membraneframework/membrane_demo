defmodule Example.Simple.Peer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer
  alias Membrane.WebRTC.Server.Room
  require Logger

  @impl true
  def parse_request(_request) do
    room_name = UUID.uuid1()

    {:ok, _pid} =
      Room.start_supervised(%Room.Options{module: Example.Simple.Room, name: room_name})

    {:ok, %{}, %{room_name: room_name}, room_name}
  end

  @impl true
  def on_init(_context, auth_data, _options) do
    {:ok, %{room_name: auth_data.metadata.room_name}}
  end

  @impl true
  def on_receive(%{event: "record"}, _context, state) do
    {:ok, _pid} = Membrane.Recording.Pipeline.start_link(%{room: state.room_name})
    {:ok, state}
  end

  @impl true
  def on_receive(message, context, state) do
    super(message, context, state)
  end
end
