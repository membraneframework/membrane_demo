defmodule VideoRoom.Pipeline do
  use Membrane.Pipeline

  alias Membrane.WebRTC.{EndpointBin, Track}

  require Membrane.Logger

  @pipeline_registry VideoRoom.PipelineRegistry

  # pipeline has to be started before any peer connects with it
  # therefore there is a possibility that pipeline won't be ever closed
  # (a peer started it but failed to join) so set a timeout at pipeline's start to check
  # if anyone joined the room and close it if no one did
  @empty_room_timeout 5000

  @spec registry() :: atom()
  def registry(), do: @pipeline_registry

  @spec lookup(String.t()) :: GenServer.server() | nil
  def lookup(room_id) do
    case Registry.lookup(@pipeline_registry, room_id) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  def start_link(room_id) do
    do_start(:start_link, room_id)
  end

  def start(room_id) do
    do_start(:start, room_id)
  end

  defp do_start(func, room_id) when func in [:start, :start_link] do
    Membrane.Logger.info("[VideoRoom.Pipeline] Starting a new pipeline for room: #{room_id}")

    apply(Membrane.Pipeline, func, [
      __MODULE__,
      [room_id],
      [name: {:via, Registry, {@pipeline_registry, room_id}}]
    ])
  end

  @impl true
  def handle_init([room_id]) do
    play(self())

    Process.send_after(self(), :check_if_empty, @empty_room_timeout)
    {:ok, %{room_id: room_id, tracks: %{}, endpoints_tracks_ids: %{}}}
  end

  @impl true
  def handle_other({:new_peer, peer_pid}, ctx, state) do
    if Map.has_key?(ctx.children, {:endpoint, peer_pid}) do
      Membrane.Logger.warn("Peer already connected, ignoring")
      {:ok, state}
    else
      Membrane.Logger.info("New peer #{inspect(peer_pid)}")
      Process.monitor(peer_pid)
      stream_id = Track.stream_id()
      tracks = [Track.new(:audio, stream_id), Track.new(:video, stream_id)]
      endpoint = {:endpoint, peer_pid}

      children = %{
        endpoint => %EndpointBin{
          outbound_tracks: Map.values(state.tracks),
          inbound_tracks: tracks
        }
      }

      links =
        flat_map_children(ctx, fn
          {:tee, track_id} = tee ->
            [
              link(tee)
              |> via_in(Pad.ref(:input, track_id),
                options: [encoding: state.tracks[track_id].encoding]
              )
              |> to(endpoint)
            ]

          _child ->
            []
        end)

      tracks_msgs =
        flat_map_children(ctx, fn
          {:endpoint, _peer_pid} = endpoint ->
            [forward: {endpoint, {:add_tracks, tracks}}]

          _child ->
            []
        end)

      spec = %ParentSpec{children: children, links: links}

      state =
        %{state | tracks: tracks |> Map.new(&{&1.id, &1}) |> Map.merge(state.tracks)}
        |> put_in([:endpoints_tracks_ids, peer_pid], Enum.map(tracks, & &1.id))

      {{:ok, [spec: spec] ++ tracks_msgs}, state}
    end
  end

  @impl true
  def handle_other({:signal, peer_pid, msg}, _ctx, state) do
    {{:ok, forward: {{:endpoint, peer_pid}, {:signal, msg}}}, state}
  end

  def handle_other({:remove_peer, peer_pid}, ctx, state) do
    case maybe_remove_peer(peer_pid, ctx, state) do
      {:absent, [], state} ->
        Membrane.Logger.info("Peer #{inspect(peer_pid)} already removed")
        {:ok, state}

      {:present, actions, state} ->
        {{:ok, actions}, state}
    end
  end

  def handle_other({:DOWN, _ref, :process, pid, _reason}, ctx, state) do
    {_status, actions, state} = maybe_remove_peer(pid, ctx, state)

    stop_if_empty(state)

    {{:ok, actions}, state}
  end

  def handle_other(:check_if_empty, _ctx, state) do
    stop_if_empty(state)
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_track, track_id, encoding}, endpoint, ctx, state) do
    Membrane.Logger.info("New incoming #{encoding} track")
    tee = {:tee, track_id}
    fake = {:fake, track_id}
    children = %{tee => Membrane.Element.Tee.Parallel, fake => Membrane.Element.Fake.Sink.Buffers}

    links =
      [link(endpoint) |> via_out(Pad.ref(:output, track_id)) |> to(tee) |> to(fake)] ++
        flat_map_children(ctx, fn
          {:endpoint, _id} = other_endpoint when endpoint != other_endpoint ->
            [
              link(tee)
              |> via_in(Pad.ref(:input, track_id), options: [encoding: encoding])
              |> to(other_endpoint)
            ]

          _child ->
            []
        end)

    spec = %ParentSpec{children: children, links: links}
    state = update_in(state, [:tracks, track_id], &%Track{&1 | encoding: encoding})
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:signal, message}, {:endpoint, peer_pid}, _ctx, state) do
    send(peer_pid, {:signal, message})
    {:ok, state}
  end

  defp maybe_remove_peer(peer_pid, ctx, state) do
    endpoint = ctx.children[{:endpoint, peer_pid}]

    if endpoint == nil or endpoint.terminating? do
      {:absent, [], state}
    else
      {tracks_ids, state} = pop_in(state, [:endpoints_tracks_ids, peer_pid])

      {tracks, state} =
        Enum.map_reduce(tracks_ids, state, fn track_id, state ->
          Bunch.Access.get_updated_in(state, [:tracks, track_id], &%Track{&1 | enabled?: false})
        end)

      children =
        tracks_ids
        |> Enum.flat_map(&[tee: &1, fake: &1])
        |> Enum.filter(&Map.has_key?(ctx.children, &1))

      children = [endpoint: peer_pid] ++ children

      tracks_msgs =
        flat_map_children(ctx, fn
          {:endpoint, id} when id != peer_pid ->
            [forward: {{:endpoint, id}, {:add_tracks, tracks}}]

          _child ->
            []
        end)

      {:present, [remove_child: children] ++ tracks_msgs, state}
    end
  end

  defp stop_if_empty(state) do
    if state.endpoints_tracks_ids == %{} do
      Membrane.Logger.info("Room '#{state.room_id}' is empty, stopping pipeline")
      Membrane.Pipeline.stop_and_terminate(self())
    end
  end

  defp flat_map_children(ctx, fun) do
    ctx.children |> Map.keys() |> Enum.flat_map(fun)
  end
end
