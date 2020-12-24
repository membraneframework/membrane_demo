defmodule RecordingDemo.Signaling.MembranePeer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer
  require Logger

  @impl true
  def parse_request(request) do
    with {:ok, room_name} <- get_room_name(request) do
      {:ok, %{}, nil, room_name}
    end
  end

  defp get_room_name(request) do
    room_name = :cowboy_req.binding(:room, request)

    if room_name == :undefined do
      {:error, :no_room_name_bound_in_url}
    else
      {:ok, room_name}
    end
  end
end
