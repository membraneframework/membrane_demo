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

        participant_id = UUID.uuid4()
        response = %{"userId" => participant_id}

        {:ok, response,
         assign(socket, %{
           room_id: room_id,
           pipeline: pipeline,
           participant_id: participant_id
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
        "start",
        %{
          "type" => type,
          "relayAudio" => relay_audio?,
          "relayVideo" => relay_video?,
          "displayName" => display_name
        },
        socket
      ) do
    type = if type == "participant", do: :participant, else: :screensharing

    params = [
      participant_id: socket.assigns.participant_id,
      relay_audio?: relay_audio?,
      relay_video?: relay_video?,
      display_name: display_name
    ]

    socket
    |> send_to_pipeline({:new_peer, self(), type, params, socket_ref(socket)})

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

  def handle_in("toggledVideo", _msg, socket) do
    socket
    |> send_to_pipeline({:toggled_video, self()})

    {:noreply, socket}
  end

  def handle_in("toggledAudio", _msg, socket) do
    socket
    |> send_to_pipeline({:toggled_audio, self()})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:signal, {:candidate, candidate, sdp_mline_index}}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "candidate",
      data: %{"candidate" => candidate, "sdpMLineIndex" => sdp_mline_index}
    })

    {:noreply, socket}
  end

  def handle_info({:signal, {:sdp_offer, sdp}}, socket) do
    push(socket, "membraneWebRTCEvent", %{type: "offer", data: %{"type" => "offer", "sdp" => sdp}})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:participant_joined, participant}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "participantJoined",
      data: %{"participant" => serialize_participant(participant)}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:participant_left, participant_id}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "participantLeft",
      data: %{"participantId" => participant_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info(
        {:signal, {:replace_participant, old_participant_id, new_participant_id}},
        socket
      ) do
    push(socket, "membraneWebRTCEvent", %{
      type: "replaceParticipant",
      data: %{"oldParticipantId" => old_participant_id, "newParticipantId" => new_participant_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:signal, {:display_participant, participant_id}}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "displayParticipant",
      data: %{"participantId" => participant_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:toggled_video, participant_id}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "toggledVideo",
      data: %{"participantId" => participant_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:toggled_audio, participant_id}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "toggledAudio",
      data: %{"participantId" => participant_id}
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_peer, response, ref}, socket) do
    case response do
      {:ok, max_display_num, participants} ->
        participants = Enum.map(participants, &serialize_participant/1)

        reply(
          ref,
          {:ok, %{maxDisplayNum: max_display_num, participants: participants}}
        )

      {:error, _reason} = error ->
        reply(ref, error)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:internal_error, message}, socket) do
    push(socket, "membraneWebRTCEvent", %{type: "error", error: message})
    {:noreply, socket}
  end

  def handle_info({:DOWN, _ref, :process, _monitor, reason}, socket) do
    push(socket, "membraneWebRTCEvent", %{
      type: "error",
      error: "Room stopped working, consider restarting your connection, #{inspect(reason)}"
    })

    {:noreply, socket}
  end

  defp send_to_pipeline(socket, message) do
    socket.assigns.pipeline |> send(message)
  end

  # przed revertem nazw eventow (jak wsyzstkie to bylo membraneWebRTCEvent) nie dzialalo np dodawanie nowych osob do pokoju

  defp serialize_participant(participant) do
    %{
      "id" => participant.id,
      "displayName" => participant.display_name,
      "mids" => participant.mids,
      "mutedAudio" => participant.muted_audio,
      "mutedVideo" => participant.muted_video
    }
  end
end
