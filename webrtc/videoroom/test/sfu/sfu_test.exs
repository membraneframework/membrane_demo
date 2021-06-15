defmodule Membrane.SFUTest do
  use ExUnit.Case

  alias Membrane.SFU

  setup do
    extension_options = [
      vad: true
    ]

    network_options = [
      stun_servers: [
        %{server_addr: "stun.l.google.com", server_port: 19_302}
      ],
      turn_servers: []
    ]

    options = [
      id: "test_sfu",
      extension_options: extension_options,
      network_options: network_options
    ]

    {:ok, pid} = SFU.start_link(options, [])

    send(pid, {:register, self()})

    [sfu_engine: pid]
  end

  describe "joining to a room" do
    test "triggers :new_peer notification when media event is valid", %{sfu_engine: sfu_engine} do
      peer_id = "sample_id"

      metadata = %{
        "displayName" => "Bob"
      }

      track_metadata = [
        %{
          "type" => "audio",
          "source" => "microphone"
        },
        %{
          "type" => "video",
          "source" => "camera"
        }
      ]

      media_event =
        %{
          "type" => "join",
          "key" => generate_key(),
          "data" => %{
            "id" => peer_id,
            "relayAudio" => true,
            "relayVideo" => true,
            "receiveMedia" => true,
            "metadata" => metadata,
            "trackMetadata" => track_metadata
          }
        }
        |> Jason.encode!()

      send(sfu_engine, {:media_event, media_event})
      assert_receive {_from, {:new_peer, ^peer_id, ^metadata, ^track_metadata}}
    end

    test ":new_peer notification is not sent after receiving join media event with improper key",
         %{sfu_engine: sfu_engine} do
      peer_id = "sample_id"

      media_event =
        %{
          type: "join",
          key: "invalid_key",
          data: %{
            id: peer_id,
            relayAudio: true,
            relayVideo: true,
            receiveMedia: true,
            metadata: %{displayName: "Bob"},
            trackMetadata: [
              %{type: "audio", source: "microphone"},
              %{type: "video", source: "camera"}
            ]
          }
        }
        |> Jason.encode!()

      send(sfu_engine, {:media_event, media_event})
      refute_receive {_from, {:new_peer, _peer_id, _metadata, _track_metadata}}
    end
  end

  describe "accepting a new peer" do
    test "triggers peerAccepted event", %{sfu_engine: sfu_engine} do
      peer_id = "sample_id"

      metadata = %{
        "displayName" => "Bob"
      }

      track_metadata = [
        %{
          "type" => "audio",
          "source" => "microphone"
        },
        %{
          "type" => "video",
          "source" => "camera"
        }
      ]

      media_event =
        %{
          type: "join",
          key: generate_key(),
          data: %{
            id: peer_id,
            relayAudio: true,
            relayVideo: true,
            receiveMedia: true,
            metadata: metadata,
            trackMetadata: track_metadata
          }
        }
        |> Jason.encode!()

      send(sfu_engine, {:media_event, media_event})
      assert_receive {_from, {:new_peer, ^peer_id, ^metadata, ^track_metadata}}
      send(sfu_engine, {:accept_new_peer, peer_id})
      assert_receive {_from, {:media_event, ^peer_id, media_event}}

      assert %{"type" => "peerAccepted", "data" => %{"id" => peer_id, "peersInRoom" => []}} ==
               Jason.decode!(media_event)
    end

    # test "accepting already accepted peer does nothing" do
    # end
  end

  defp generate_key() do
    "#{UUID.uuid4()}"
  end
end
