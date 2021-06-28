defmodule Membrane.SFU.MediaEvent do
  def create_peer_accepted_event(peer_id, peers) do
    peers =
      Enum.map(peers, fn peer ->
        %{id: peer.id, metadata: peer.metadata, midToTrackMetadata: peer.mid_to_track_metadata}
      end)

    %{type: "peerAccepted", data: %{id: peer_id, peersInRoom: peers}}
    |> do_create(peer_id)
  end

  def create_peer_denied_event(peer_id) do
    %{type: "peerDenied"}
    |> do_create(peer_id)
  end

  def create_peer_joined_event(peer_id, metadata, mid_to_track_metadata) do
    %{
      type: "peerJoined",
      data: %{
        peer: %{
          id: peer_id,
          metadata: metadata,
          midToTrackMetadata: mid_to_track_metadata
        }
      }
    }
    |> do_create(:broadcast)
  end

  def create_peer_left_event(peer_id) do
    %{
      type: "peerLeft",
      data: %{
        peerId: peer_id
      }
    }
    |> do_create(:broadcast)
  end

  def create_signal_event(peer_id, {:signal, {:candidate, candidate, sdp_m_line_index}}) do
    %{
      type: "candidate",
      data: %{
        candidate: candidate,
        sdpMLineIndex: sdp_m_line_index,
        sdpMid: nil,
        usernameFragment: nil
      }
    }
    |> do_create(peer_id)
  end

  def create_signal_event(peer_id, {:signal, {:sdp_offer, offer}}) do
    %{
      type: "sdpOffer",
      data: %{
        type: "offer",
        sdp: offer
      }
    }
    |> do_create(peer_id)
  end

  def create_error_event(to, msg) do
    %{
      type: "error",
      data: %{
        message: msg
      }
    }
    |> do_create(to)
  end

  defp do_create(event, to) do
    event
    |> serialize()
    |> then(fn event -> {:media_event, to, event} end)
  end

  def serialize(event), do: Jason.encode!(event)

  def deserialize(raw_event) do
    case Jason.decode(raw_event) do
      {:ok, event} -> do_deserialize(event)
      _error -> {:error, :invalid_media_event}
    end
  end

  defp do_deserialize(%{"type" => "join"} = event) do
    try do
      %{
        "type" => "join",
        "data" => %{
          "relayAudio" => relay_audio,
          "relayVideo" => relay_video,
          "receiveMedia" => receive_media,
          "metadata" => metadata,
          "trackMetadata" => track_metadata
        }
      } = event

      if length(Map.keys(event)) != 2 or length(Map.keys(event["data"])) != 5 do
        {:error, :invalid_media_event}
      else
        {:ok,
         %{
           type: :join,
           data: %{
             relay_audio: relay_audio,
             relay_video: relay_video,
             receive_media: receive_media,
             metadata: metadata,
             track_metadata: track_metadata
           }
         }}
      end
    rescue
      _error ->
        {:error, :invalid_media_event}
    end
  end

  defp do_deserialize(%{"type" => "sdpAnswer"} = event) do
    try do
      %{
        "type" => "sdpAnswer",
        "data" => %{
          "sdpAnswer" => %{
            "type" => "answer",
            "sdp" => sdp
          },
          "midToTrackMetadata" => mid_to_track_metadata
        }
      } = event

      if length(Map.keys(event)) != 2 or length(Map.keys(event["data"])) != 2 or
           length(Map.keys(event["data"]["sdpAnswer"])) != 2 do
        {:error, :invalid_media_event}
      else
        {:ok,
         %{
           type: :sdp_answer,
           data: %{
             sdp_answer: %{
               type: :answer,
               sdp: sdp
             },
             mid_to_track_metadata: mid_to_track_metadata
           }
         }}
      end
    rescue
      _error ->
        {:error, :invalid_media_event}
    end
  end

  defp do_deserialize(%{"type" => "candidate"} = event) do
    try do
      %{
        "type" => "candidate",
        "data" => %{
          "candidate" => candidate,
          "sdpMLineIndex" => sdp_m_line_index
        }
      } = event

      if length(Map.keys(event)) != 2 or length(Map.keys(event["data"])) != 2 do
        {:error, :invalid_media_event}
      else
        {:ok,
         %{
           type: :candidate,
           data: %{
             candidate: candidate,
             sdp_m_line_index: sdp_m_line_index
           }
         }}
      end
    rescue
      _error ->
        {:error, :invalid_media_event}
    end
  end

  defp do_deserialize(%{"type" => "leave"} = event) do
    try do
      %{"type" => "leave"} = event

      if length(Map.keys(event)) != 1 do
        {:error, :invalid_media_event}
      else
        {:ok, %{type: :leave}}
      end
    rescue
      _error ->
        {:error, :invalid_media_event}
    end
  end
end
