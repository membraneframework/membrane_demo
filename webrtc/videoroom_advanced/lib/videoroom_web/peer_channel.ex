defmodule VideoRoomWeb.PeerChannel do
  use Phoenix.Channel

  require Logger

  @impl true
  def join("room:" <> room_id, _params, socket) do
    case :global.whereis_name(room_id) do
      :undefined -> Videoroom.Room.start(name: {:global, room_id})
      pid -> {:ok, pid}
    end
    |> case do
      {:ok, room} ->
        peer_id = "#{UUID.uuid4()}"
        # TODO handle crash of room?
        Process.monitor(room)
        Videoroom.Room.add_peer_channel(room, self(), peer_id)
        {:ok, Phoenix.Socket.assign(socket, %{room_id: room_id, room: room, peer_id: peer_id})}

      {:error, reason} ->
        Logger.error("""
        Failed to start room.
        Room: #{inspect(room_id)}
        Reason: #{inspect(reason)}
        """)

        {:error, %{reason: "failed to start room"}}
    end
  end

  @impl true
  def handle_in("mediaEvent", %{"data" => event}, socket) do
    send(socket.assigns.room, {:media_event, socket.assigns.peer_id, event})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:media_event, event}, socket) do
    push(socket, "mediaEvent", %{data: event})

    {:noreply, socket}
  end
end
