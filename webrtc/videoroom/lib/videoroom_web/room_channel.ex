defmodule VideoRoomWeb.RoomChannel do
  use Phoenix.Channel

  require Logger

  # @prefix "[RoomChannel]"

  intercept(["signal"])

  @impl true
  def join("room:" <> room_id, _message, socket) do
    # Logger.info("#{@prefix} New user joined room channel")
    {:ok, assign(socket, :room_id, room_id)}
  end

  @impl true
  def handle_in("start", _msg, socket) do
    socket
    |> socket_room()
    |> send_to_pipeline({:new_peer, self()})

    {:noreply, socket}
  end

  def handle_in("answer", %{"data" => %{"sdp" => sdp}}, socket) do
    socket
    |> socket_room()
    |> send_to_pipeline({:signal, self(), {:sdp_answer, sdp}})

    {:noreply, socket}
  end

  def handle_in("candidate", %{"data" => %{"candidate" => candidate}}, socket) do
    socket
    |> socket_room()
    |> send_to_pipeline({:signal, self(), {:candidate, candidate}})

    {:noreply, socket}
  end

  def handle_in("stop", _msg, socket) do
    socket
    |> socket_room()
    |> send_to_pipeline({:remove_peer, self()})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:signal, {:candidate, candidate, sdp_mline_index}}, socket) do
    push(socket, "candidate", %{
      data: %{"candidate" => candidate, "sdpMLineIndex" => sdp_mline_index}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:signal, {:sdp_offer, sdp}}, socket) do
    push(socket, "offer", %{data: %{"type" => "offer", "sdp" => sdp}})
    {:noreply, socket}
  end

  defp send_to_pipeline(_room_id, message) do
    # TODO: add pipeline registry mapping room_id to pipeline
    # for multiple videorooms
    send(VideoRoom.Pipeline, message)
  end

  defp socket_room(socket), do: socket.assigns.room_id
end
