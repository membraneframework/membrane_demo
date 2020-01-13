defmodule Example.Simple.Room do
  @moduledoc false
  use Membrane.WebRTC.Server.Room

  @impl true
  def on_init(options) do
    {:ok, %{number_of_peers: 0, max_peers: options.max_peers}}
  end

  @impl true
  def on_join(_auth_data, state) do
    current_number = state.number_of_peers

    if current_number < state.max_peers do
      {:ok, Map.put(state, :number_of_peers, current_number + 1)}
    else
      {{:error, :room_is_full}, state}
    end
  end

  @impl true
  def on_leave(_peer_id, state) do
    {:ok, Map.put(state, :number_of_peers, state.number_of_peers - 1)}
  end
end
