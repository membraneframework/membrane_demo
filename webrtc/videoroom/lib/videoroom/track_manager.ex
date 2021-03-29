defmodule VideoRoom.TrackManager do
  require Membrane.Logger

  @type t :: map()
  @type track_id_t :: any()

  def new(opts) do
    %{
      displayed: %{},
      queued: MapSet.new(),
      rest: MapSet.new(),
      max_display_num: opts[:max_display_num]
    }
  end

  @spec add_track(t(), track_id :: track_id_t()) ::
          {:ok | {:send_track, track_id :: track_id_t()}, t()}
  def add_track(state, track_id) do
    if length(Map.keys(state.displayed)) < state.max_display_num do
      state = put_in(state.displayed[track_id], :silence)
      {{:send_track, track_id}, state}
    else
      state = %{state | rest: MapSet.put(state.rest, track_id)}
      {:ok, state}
    end
  end

  @spec update_track(t(), track_id :: track_id_t(), activity :: :speech | :silence) ::
          {:ok | {:replace_track, old_track_id :: track_id_t(), new_track_id :: track_id_t()},
           t()}
  def update_track(state, track_id, :speech) do
    cond do
      Map.has_key?(state.displayed, track_id) ->
        state = put_in(state.displayed[track_id], :speech)
        {:ok, state}

      MapSet.member?(state.queued, track_id) ->
        {:ok, state}

      MapSet.member?(state.rest, track_id) ->
        case find_inactive_track(state) do
          {nil, nil} ->
            state = %{state | queued: MapSet.put(state.queued, track_id)}
            state = %{state | rest: MapSet.delete(state.rest, track_id)}
            {:ok, state}

          {inactive_track_id, :silence} ->
            state = %{state | displayed: Map.delete(state.displayed, inactive_track_id)}
            state = %{state | rest: MapSet.put(state.rest, inactive_track_id)}
            state = %{state | rest: MapSet.delete(state.rest, track_id)}
            state = put_in(state.displayed[track_id], :speech)
            {{:replace_track, inactive_track_id, track_id}, state}
        end

      true ->
        Membrane.Logger.warn("No such track id #{inspect(track_id)}")
        {:error, :no_such_track_id}
    end
  end

  def update_track(state, track_id, :silence) do
    cond do
      Map.has_key?(state.displayed, track_id) ->
        if MapSet.size(state.queued) == 0 do
          state = put_in(state.displayed[track_id], :silence)
          {:ok, state}
        else
          queued_track_id = MapSet.to_list(state.queued) |> List.first()
          state = %{state | displayed: Map.delete(state.displayed, track_id)}
          state = %{state | rest: MapSet.put(state.rest, track_id)}
          state = %{state | queued: MapSet.delete(state.queued, queued_track_id)}
          state = %{state | displayed: Map.put(state.displayed, queued_track_id, :speech)}
          {{:replace_track, track_id, queued_track_id}, state}
        end

      MapSet.member?(state.queued, track_id) ->
        state = %{state | queued: MapSet.delete(state.queued, track_id)}
        state = %{state | rest: MapSet.put(state.queued, track_id)}
        {:ok, state}

      MapSet.member?(state.rest, track_id) ->
        {:ok, state}

      true ->
        Membrane.Logger.warn("No such track id #{inspect(track_id)}")
        {:error, :no_such_track_id}
    end
  end

  defp find_inactive_track(state) do
    # finds track that is inactive but displayed
    Enum.find(state.displayed, {nil, nil}, fn {_track_id, activity} ->
      activity == :silence
    end)
  end
end
