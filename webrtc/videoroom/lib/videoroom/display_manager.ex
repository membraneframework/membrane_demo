defmodule VideoRoom.DisplayManager do
  require Membrane.Logger

  @type endpoint_id_t :: any()
  @opaque t :: %__MODULE__{
            owner: endpoint_id_t(),
            displayed: %{},
            queued: MapSet.t(),
            rest: MapSet.t(),
            max_display_num: non_neg_integer()
          }

  @enforce_keys [:owner, :displayed, :queued, :rest, :max_display_num]
  defstruct @enforce_keys

  def new(owner, max_display_num) do
    %__MODULE__{
      owner: owner,
      displayed: %{},
      queued: MapSet.new(),
      rest: MapSet.new(),
      max_display_num: max_display_num
    }
  end

  @spec add(t(), endpoint_id :: endpoint_id_t()) :: t()
  def add(state, endpoint_id) do
    if map_size(state.displayed) < state.max_display_num,
      do: put_in(state.displayed[endpoint_id], :silence),
      else: %{state | rest: MapSet.put(state.rest, endpoint_id)}
  end

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
            state = %{state | queued: MapSet.put(state.queued, endpoint_id)}
            state = %{state | rest: MapSet.delete(state.rest, endpoint_id)}
            {:ok, state}

          {inactive_endpoint_id, :silence} ->
            state = %{state | displayed: Map.delete(state.displayed, inactive_endpoint_id)}
            state = %{state | rest: MapSet.put(state.rest, inactive_endpoint_id)}
            state = %{state | rest: MapSet.delete(state.rest, endpoint_id)}
            state = put_in(state.displayed[endpoint_id], :speech)
            {{:replace, inactive_endpoint_id, endpoint_id}, state}
        end

      true ->
        Membrane.Logger.warn("No such endpoint id #{inspect(endpoint_id)}")
        {:error, :no_such_endpoint_id}
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
          state = %{state | displayed: Map.delete(state.displayed, endpoint_id)}
          state = %{state | rest: MapSet.put(state.rest, endpoint_id)}
          state = %{state | queued: MapSet.delete(state.queued, queued_endpoint_id)}
          state = %{state | displayed: Map.put(state.displayed, queued_endpoint_id, :speech)}
          {{:replace, endpoint_id, queued_endpoint_id}, state}
        end

      MapSet.member?(state.queued, endpoint_id) ->
        state = %{state | queued: MapSet.delete(state.queued, endpoint_id)}
        state = %{state | rest: MapSet.put(state.queued, endpoint_id)}
        {:ok, state}

      MapSet.member?(state.rest, endpoint_id) ->
        {:ok, state}

      true ->
        Membrane.Logger.warn("No such endpoint id #{inspect(endpoint_id)}")
        {:error, :no_such_endpoint_id}
    end
  end

  @spec remove(t(), endpoint_id :: endpoint_id_t()) ::
          {:ok
           | {:stop, endpoint_id :: endpoint_id_t()}
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
            state = %{state | rest: MapSet.delete(state.rest, rest_endpoint_id)}
            state = %{state | displayed: Map.put(state.displayed, rest_endpoint_id, :silence)}
            {{:replace, endpoint_id, rest_endpoint_id}, state}
          end
        else
          queued_endpoint_id = MapSet.to_list(state.queued) |> List.first()
          state = %{state | displayed: Map.delete(state.displayed, endpoint_id)}
          state = %{state | queued: MapSet.delete(state.queued, queued_endpoint_id)}
          state = %{state | displayed: Map.put(state.displayed, queued_endpoint_id, :speech)}
          {{:replace, endpoint_id, queued_endpoint_id}, state}
        end

      MapSet.member?(state.queued, endpoint_id) ->
        state = %{state | queued: MapSet.delete(state.queued, endpoint_id)}
        {:ok, state}

      MapSet.member?(state.rest, endpoint_id) ->
        state = %{state | rest: MapSet.delete(state.rest, endpoint_id)}
        {:ok, state}

      true ->
        Membrane.Logger.warn("No such endpoint id #{inspect(endpoint_id)}")
        {:error, :no_such_endpoint_id}
    end
  end

  def display?(state, endpoint_id), do: Map.has_key?(state.displayed, endpoint_id)

  def get_max_display_num(state), do: state.max_display_num

  defp find_inactive(state) do
    # finds endpoint which audio track is inactive but video track is displayed
    Enum.find(state.displayed, {nil, nil}, fn {_endpoint_id, activity} ->
      activity == :silence
    end)
  end
end
