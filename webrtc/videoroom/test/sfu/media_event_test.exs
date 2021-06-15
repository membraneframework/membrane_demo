defmodule Membrane.SFU.MediaEventTest do
  use ExUnit.Case

  alias Membrane.SFU.MediaEvent

  describe "deserializing join media event" do
    test "creates proper map when event is valid" do
      peer_id = "sample_id"
      key = generate_key()

      raw_media_event =
        %{
          "type" => "join",
          "key" => key,
          "data" => %{
            "id" => peer_id,
            "relayAudio" => true,
            "relayVideo" => true,
            "receiveMedia" => true,
            "metadata" => %{"displayName" => "Bob"},
            "trackMetadata" => [
              %{"type" => "audio", "source" => "microphone"},
              %{"type" => "video", "source" => "camera"}
            ]
          }
        }
        |> Jason.encode!()

      expected_media_event = %{
        type: :join,
        key: key,
        data: %{
          id: peer_id,
          relay_audio: true,
          relay_video: true,
          receive_media: true,
          metadata: %{"displayName" => "Bob"},
          track_metadata: [
            %{"type" => "audio", "source" => "microphone"},
            %{"type" => "video", "source" => "camera"}
          ]
        }
      }

      assert {:ok, expected_media_event} == MediaEvent.deserialize(raw_media_event)
    end

    test "returns error when event misses key" do
      peer_id = "sample_id"
      key = generate_key()

      raw_media_event =
        %{
          "type" => "join",
          "key" => key,
          "data" => %{
            "id" => peer_id,
            "relayAudio" => true,
            # missing relayVideo field
            "receiveMedia" => true,
            "metadata" => %{"displayName" => "Bob"},
            "trackMetadata" => [
              %{"type" => "audio", "source" => "microphone"},
              %{"type" => "video", "source" => "camera"}
            ]
          }
        }
        |> Jason.encode!()

      assert {:error, :invalid_media_event} == MediaEvent.deserialize(raw_media_event)
    end

    test "returns error when event has too many keys" do
      peer_id = "sample_id"
      key = generate_key()

      raw_media_event =
        %{
          "type" => "join",
          "key" => key,
          "someAdditionalField" => "someAdditionalValue",
          "data" => %{
            "id" => peer_id,
            "relayAudio" => true,
            "relayVideo" => true,
            "receiveMedia" => true,
            "metadata" => %{"displayName" => "Bob"},
            "trackMetadata" => [
              %{"type" => "audio", "source" => "microphone"},
              %{"type" => "video", "source" => "camera"}
            ]
          }
        }
        |> Jason.encode!()

      assert {:error, :invalid_media_event} == MediaEvent.deserialize(raw_media_event)
    end

    test "returns error when event has too many keys in data map" do
      peer_id = "sample_id"
      key = generate_key()

      raw_media_event =
        %{
          "type" => "join",
          "key" => key,
          "data" => %{
            "id" => peer_id,
            "relayAudio" => true,
            "relayVideo" => true,
            "receiveMedia" => true,
            "metadata" => %{"displayName" => "Bob"},
            "trackMetadata" => [
              %{"type" => "audio", "source" => "microphone"},
              %{"type" => "video", "source" => "camera"}
            ],
            "someAdditionalField" => "someAdditionalValue"
          }
        }
        |> Jason.encode!()

      assert {:error, :invalid_media_event} == MediaEvent.deserialize(raw_media_event)
    end
  end

  defp generate_key() do
    "#{UUID.uuid4()}"
  end
end
