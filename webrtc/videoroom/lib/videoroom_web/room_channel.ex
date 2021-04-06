defmodule VideoRoomWeb.RoomChannel do
  use Phoenix.Channel

  require Logger

  @impl true
  def join("room:" <> room_id, _msg, socket) do
    {room_id, is_screensharing} =
      case room_id do
        "screensharing:" <> id ->
          {id, true}

        ^room_id ->
          {room_id, false}
      end

    case VideoRoom.Pipeline.lookup(room_id) do
      nil -> VideoRoom.Pipeline.start(room_id)
      pid -> {:ok, pid}
    end
    |> case do
      {:ok, pipeline} ->
        Process.monitor(pipeline)

        {:ok,
         assign(socket, %{
           room_id: room_id,
           pipeline: pipeline,
           is_screensharing: is_screensharing
         })}

      {:error, reason} ->
        Logger.error("""
        Failed to start pipeline
        Room: #{inspect(room_id)}
        Reason: #{inspect(reason)}
        """)

        {:error, %{reason: "failed to start room"}}
    end
  end

  @impl true
  def handle_in("start", _msg, socket) do
    type = if socket.assigns.is_screensharing, do: :screensharing, else: :participant

    socket
    |> send_to_pipeline({:new_peer, self(), type, socket_ref(socket)})

    {:noreply, socket}
  end

  def handle_in("answer", %{"data" => %{"sdp" => sdp}}, socket) do
    socket
    |> send_to_pipeline({:signal, self(), {:sdp_answer, sdp}})

    {:noreply, socket}
  end

  def handle_in("candidate", %{"data" => %{"candidate" => candidate}}, socket) do
    socket
    |> send_to_pipeline({:signal, self(), {:candidate, candidate}})

    {:noreply, socket}
  end

  def handle_in("stop", _msg, socket) do
    socket
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

  def handle_info({:signal, {:sdp_offer, sdp}}, socket) do
    push(socket, "offer", %{data: %{"type" => "offer", "sdp" => sdp}})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_peer, response, ref}, socket) do
    case response do
      :ok ->
        reply(ref, {:ok, %{}})

      {:error, _reason} = error ->
        reply(ref, error)
    end

    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _monitor, reason}, socket) do
    push(socket, "error", %{
      error: "Room stopped working, consider restarting your connection, #{inspect(reason)}"
    })

    {:noreply, socket}
  end

  defp send_to_pipeline(socket, message) do
    socket.assigns.pipeline |> send(message)
  end
end
