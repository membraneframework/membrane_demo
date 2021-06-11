defmodule VideoRoomWeb.RoomChannel do
  use Phoenix.Channel

  require Logger

  @impl true
  def join("room:" <> room_id, _params, socket) do
    # FIXME: make use of structs that are serialized to/from camel case to snake case existing atoms

    room_id =
      case room_id do
        "screensharing:" <> id -> id
        id -> id
      end

    case VideoRoom.Pipeline.lookup(room_id) do
      nil -> VideoRoom.Pipeline.start(room_id)
      pid -> {:ok, pid}
    end
    |> case do
      {:ok, pipeline} ->
        Process.monitor(pipeline)

        peer_id = UUID.uuid4()
        response = %{"userId" => peer_id}

        {:ok, response,
         assign(socket, %{
           room_id: room_id,
           pipeline: pipeline,
           peer_id: peer_id
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
  def handle_in(
        "mediaEvent",
        %{
          "type" => "start",
          "payload" => %{
            "type" => type,
            "relayAudio" => relay_audio?,
            "relayVideo" => relay_video?,
            "displayName" => display_name
          }
        },
        socket
      ) do
    type = if type == "participant", do: :participant, else: :screensharing

    params = [
      peer_id: socket.assigns.peer_id,
      relay_audio?: relay_audio?,
      relay_video?: relay_video?,
      display_name: display_name
    ]

    socket
    |> send_to_pipeline({:new_peer, self(), type, params, socket_ref(socket)})

    {:noreply, socket}
  end

  def handle_in("mediaEvent", %{"type" => "answer", "payload" => %{"sdp" => sdp}}, socket) do
    socket
    |> send_to_pipeline({:signal, self(), {:sdp_answer, sdp}})

    {:noreply, socket}
  end

  def handle_in(
        "mediaEvent",
        %{"type" => "candidate", "payload" => %{"candidate" => candidate}},
        socket
      ) do
    socket
    |> send_to_pipeline({:signal, self(), {:candidate, candidate}})

    {:noreply, socket}
  end

  def handle_in("mediaEvent", %{"type" => "stop"}, socket) do
    socket
    |> send_to_pipeline({:remove_peer, self()})

    {:noreply, socket}
  end

  def handle_in("mediaEvent", %{"type" => "toggledVideo"}, socket) do
    socket
    |> send_to_pipeline({:toggled_video, self()})

    {:noreply, socket}
  end

  def handle_in("mediaEvent", %{"type" => "toggledAudio"}, socket) do
    socket
    |> send_to_pipeline({:toggled_audio, self()})

    {:noreply, socket}
  end

  def handle_in("getMaxDisplayNum", _msg, socket) do
    socket
    |> send_to_pipeline({:get_max_display_num, self(), socket_ref(socket)})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:signal, {:candidate, candidate, sdp_mline_index}}, socket) do
    push(socket, "mediaEvent", %{
      type: "candidate",
      data: %{"candidate" => candidate, "sdpMLineIndex" => sdp_mline_index}
    })

    {:noreply, socket}
  end

  def handle_info({:signal, {:sdp_offer, sdp}}, socket) do
    push(socket, "mediaEvent", %{type: "offer", data: %{"type" => "offer", "sdp" => sdp}})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:peer_joined, peer}, socket) do
    push(socket, "mediaEvent", %{
      type: "peerJoined",
      data: %{"peer" => serialize_peer(peer)}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:peer_left, peer_id}, socket) do
    push(socket, "mediaEvent", %{
      type: "peerLeft",
      data: %{"peerId" => peer_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:signal, {:replace_peer, old_peer_id, new_peer_id}},
        socket
      ) do
    push(socket, "replacePeer", %{
      data: %{"oldPeerId" => old_peer_id, "newPeerId" => new_peer_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:signal, {:display_peer, peer_id}}, socket) do
    push(socket, "displayPeer", %{
      data: %{"peerId" => peer_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:toggled_video, peer_id}, socket) do
    push(socket, "mediaEvent", %{
      type: "toggledVideo",
      data: %{"peerId" => peer_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:toggled_audio, peer_id}, socket) do
    push(socket, "mediaEvent", %{
      type: "toggledAudio",
      data: %{"peerId" => peer_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_peer, response, ref}, socket) do
    case response do
      {:ok, peers} ->
        peers = Enum.map(peers, &serialize_peer/1)

        reply(
          ref,
          {:ok, %{peers: peers}}
        )

      {:error, _reason} = error ->
        reply(ref, error)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:max_display_num, max_display_num, ref}, socket) do
    reply(ref, {:ok, %{"maxDisplayNum" => max_display_num}})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:internal_error, message}, socket) do
    push(socket, "mediaEvent", %{type: "error", error: message})
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _monitor, reason}, socket) do
    push(socket, "mediaEvent", %{
      type: "error",
      error: "Room stopped working, consider restarting your connection, #{inspect(reason)}"
    })

    {:noreply, socket}
  end

  defp send_to_pipeline(socket, message) do
    socket.assigns.pipeline |> send(message)
  end

  defp serialize_peer(peer) do
    %{
      "id" => peer.id,
      "displayName" => peer.display_name,
      "mids" => peer.mids,
      "mutedAudio" => peer.muted_audio,
      "mutedVideo" => peer.muted_video
    }
  end
end
