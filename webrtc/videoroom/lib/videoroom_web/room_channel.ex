defmodule VideoRoomWeb.RoomChannel do
  use Phoenix.Channel

  require Logger

  @impl true
  def join("room:" <> room_id, _params, socket) do
    case Registry.lookup(Membrane.Room.Registry, room_id) do
      [{pid, _value}] -> {:ok, pid}
      [] -> Membrane.Room.start(name: {:via, Registry, {Membrane.Room.Registry, room_id}})
    end
    |> case do
      {:ok, room} ->
        Process.monitor(room)
        {:ok, assign(socket, %{room_id: room_id, room: room})}

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
  def handle_in("mediaEvent", %{data: event}, socket) do
    send_to_room(socket, {:media_event, event})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:media_event, event}, socket) do
    push(socket, "mediaEvent", %{data: event})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _monitor, reason}, socket) do
    push(socket, "mediaEvent", %{
      type: "error",
      error: "Room stopped working, consider restarting your connection, #{inspect(reason)}"
    })

    {:noreply, socket}
  end

  defp send_to_room(socket, message) do
    socket.assigns.pipeline |> send(message)
  end
end
