defmodule Example.Simple.Peer do
  @moduledoc false

  use Membrane.WebRTC.Server.Peer
  require Logger

  @impl true
  def parse_request(request) do
    with {:ok, room_name} <- get_room_name(request),
         {:ok, credentials} <- get_credentials(request) do
      {:ok, credentials, nil, room_name}
    end
  end

  defp get_credentials(request) do
    case :cowboy_req.parse_cookies(request) |> List.keyfind("credentials", 0) do
      {"credentials", json} ->
        Jason.decode(json)

      _ ->
        {:error, :no_credentials_passed}
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

  @impl true
  def on_init(_context, auth_data, _options) do
    username = Map.get(auth_data.credentials, "username")
    password = Map.get(auth_data.credentials, "password")

    if username == "USERNAME" and password == "PASSWORD" do
      {:ok, %{}}
    else
      {:error, :wrong_credentials}
    end
  end
end
