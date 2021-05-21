defmodule VideoRoom.DisplayManager do
  @moduledoc false
  # Module that manages endpoint's tracks i.e. it indicates which tracks should be sent and which disabled in order not
  # to exceed maximal number of video tracks to display.
  require Membrane.Logger

  @type endpoint_id_t :: any()
  @opaque t :: %__MODULE__{
            displayed: %{},
            queued: MapSet.t(),
            rest: MapSet.t(),
            max_display_num: non_neg_integer()
          }

  @enforce_keys [:displayed, :queued, :rest, :max_display_num]
  defstruct @enforce_keys

  def new(max_display_num) do
    %__MODULE__{
      displayed: %{},
      queued: MapSet.new(),
      rest: MapSet.new(),
      max_display_num: max_display_num
    }
  end

  @doc """
  Adds new endpoint.

  If some endpoint is going to send video tracks of endpoint with id `endpoint_id` then this function should be called.
  """
  @spec add(t(), endpoint_id :: endpoint_id_t()) :: t()
  def add(state, endpoint_id) do
    if map_size(state.displayed) < state.max_display_num,
      do: put_in(state.displayed[endpoint_id], :silence),
      else: %{state | rest: MapSet.put(state.rest, endpoint_id)}
  end

  @doc """
  Updates voice activity status of endpoint with id `endpoint_id`. Raises if endpoint doesn't exist.

  Returns `{:replace, old_endpoint_id, new_endpoint_id}` if video track of `old_endpoint_id` should be replaced by
  video track of `new_endpoint_id`.
  Otherwise it returns `:ok`.
  """
  @spec update(t(), endpoint_id :: endpoint_id_t(), activity :: :speech | :silence) ::
          {:ok
           | {:replace, old_endpoint_id :: endpoint_id_t(), new_endpoint_id :: endpoint_id_t()},
           t()}
  def update(state, endpoint_id, :speech) do
    cond do
      Map.has_key?(state.displayed, endpoint_id) ->
        state = put_in(state.displayed[endpoint_id], :speech)
        {:ok, state}

      MapSet.member?(state.queued, endpoint_id) ->
        {:ok, state}

      MapSet.member?(state.rest, endpoint_id) ->
        case find_inactive(state) do
          {nil, nil} ->
            {:ok, move(endpoint_id, :rest, :queued, state)}

          {inactive_endpoint_id, :silence} ->
            state = swap({inactive_endpoint_id, :displayed}, {endpoint_id, :rest}, :speech, state)
            {{:replace, inactive_endpoint_id, endpoint_id}, state}
        end

      true ->
        raise("No such endpoint id #{inspect(endpoint_id)}")
    end
  end

  def update(state, endpoint_id, :silence) do
    cond do
      Map.has_key?(state.displayed, endpoint_id) ->
        if MapSet.size(state.queued) == 0 do
          state = put_in(state.displayed[endpoint_id], :silence)
          {:ok, state}
        else
          queued_endpoint_id = MapSet.to_list(state.queued) |> List.first()
          state = move({endpoint_id, :displayed}, :rest, state)
          state = move({queued_endpoint_id, :queued}, :displayed, :speech, state)

          {{:replace, endpoint_id, queued_endpoint_id}, state}
        end

      MapSet.member?(state.queued, endpoint_id) ->
        {:ok, move(endpoint_id, :queued, :rest, state)}

      MapSet.member?(state.rest, endpoint_id) ->
        {:ok, state}

      true ->
        raise("No such endpoint id #{inspect(endpoint_id)}")
    end
  end

  @doc """
  Removes endpoint with id `endpoint_id` if it exists.

  Returns `{:replace, old_endpoint_id, new_endpoint_id}` if video track of `new_endpoint_id` should be sent instead of
  video track of `old_endpoint_id`.
  Otherwise it returns `:ok`.
  """
  @spec remove(t(), endpoint_id :: endpoint_id_t()) ::
          {:ok
           | {:replace, old_endpoint_id :: endpoint_id_t(), new_endpoint_id :: endpoint_id_t()},
           t()}
  def remove(state, endpoint_id) do
    cond do
      Map.has_key?(state.displayed, endpoint_id) ->
        if MapSet.size(state.queued) == 0 do
          rest_endpoint_id = MapSet.to_list(state.rest) |> List.first()

          if rest_endpoint_id == nil do
            # there is no alternative to display
            state = %{state | displayed: Map.delete(state.displayed, endpoint_id)}
            {:ok, state}
          else
            state = %{state | displayed: Map.delete(state.displayed, endpoint_id)}
            state = move({rest_endpoint_id, :rest}, :displayed, :silence, state)
            {{:replace, endpoint_id, rest_endpoint_id}, state}
          end
        else
          queued_endpoint_id = MapSet.to_list(state.queued) |> List.first()
          state = %{state | displayed: Map.delete(state.displayed, endpoint_id)}
          state = move({queued_endpoint_id, :queued}, :displayed, :speech, state)
          {{:replace, endpoint_id, queued_endpoint_id}, state}
        end

      MapSet.member?(state.queued, endpoint_id) ->
        state = %{state | queued: MapSet.delete(state.queued, endpoint_id)}
        {:ok, state}

      MapSet.member?(state.rest, endpoint_id) ->
        state = %{state | rest: MapSet.delete(state.rest, endpoint_id)}
        {:ok, state}

      true ->
        # endpoint may have no video tracks therefore it is not present in display manager
        Membrane.Logger.debug("No such endpoint id #{inspect(endpoint_id)}")
        {:ok, state}
    end
  end

  @doc """
  Returns information if video track of given endpoint should be displayed.

  Returns `false` if there is not enough space for new video track.
  """
  def display?(state, endpoint_id), do: Map.has_key?(state.displayed, endpoint_id)

  def get_max_display_num(state), do: state.max_display_num

  defp find_inactive(state) do
    # finds endpoint which audio track is inactive but video track is displayed
    Enum.find(state.displayed, {nil, nil}, fn {_endpoint_id, activity} ->
      activity == :silence
    end)
  end

  defp swap({key, map}, {elem, set}, val, state) do
    # moves `key` from `map` to `set` and `elem` from `set` to `map` with value `val`
    state = move({key, map}, set, state)
    move({elem, set}, map, val, state)
  end

  defp move({elem, set}, map, val, state) do
    # moves `elem` from `set` to `map` with value `val`
    state = Map.put(state, set, MapSet.delete(Map.get(state, set), elem))
    Map.put(state, map, Map.put(Map.get(state, map), elem, val))
  end

  defp move(elem, src_set, dst_set, state) do
    # moves `elem` from `src_set` to `dst_set`
    state = Map.put(state, src_set, MapSet.delete(Map.get(state, src_set), elem))
    Map.put(state, dst_set, MapSet.put(Map.get(state, dst_set), elem))
  end

  defp move({key, map}, set, state) do
    # moves `key` from `map` to `set`
    state = Map.put(state, map, Map.delete(Map.get(state, map), key))
    Map.put(state, set, MapSet.put(Map.get(state, set), key))
  end
end
