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
    {:ok, %{room_id: room_id, tracks: %{}, endpoints_tracks_ids: %{}, active_screensharing: nil}}
  end

  @impl true
  def handle_other(
        {:new_peer, peer_pid, :screensharing, ref},
        _ctx,
        %{active_screensharing: screensharing} = state
      )
      when is_pid(screensharing) do
    send(peer_pid, {:new_peer, {:error, "Screensharing is already active"}, ref})
    {:ok, state}
  end

  @impl true
  def handle_other({:new_peer, peer_pid, peer_type, ref}, ctx, state) do
    send(peer_pid, {:new_peer, :ok, ref})

    if Map.has_key?(ctx.children, {:endpoint, peer_pid}) do
      Membrane.Logger.warn("Peer already connected, ignoring")
      {:ok, state}
    else
      Membrane.Logger.info("New peer #{inspect(peer_pid)} of type #{inspect(peer_type)}")
      Process.monitor(peer_pid)

      tracks = new_tracks(peer_type)

      endpoint = {:endpoint, peer_pid}

      stun_servers =
        parse_stun_servers(Application.fetch_env!(:membrane_videoroom_demo, :stun_servers))

      turn_servers =
        parse_turn_servers(Application.fetch_env!(:membrane_videoroom_demo, :turn_servers))

      children = %{
        endpoint => %EndpointBin{
          # screensharing type should not receive any streams
          outbound_tracks: if(peer_type == :participant, do: Map.values(state.tracks), else: []),
          inbound_tracks: tracks,
          stun_servers: stun_servers,
          turn_servers: turn_servers
        }
      }

      links = new_peer_links(peer_type, endpoint, ctx, state)

      tracks_msgs =
        flat_map_children(ctx, fn
          {:endpoint, _peer_pid} = endpoint ->
            [forward: {endpoint, {:add_tracks, tracks}}]

          _child ->
            []
        end)

      spec = %ParentSpec{children: children, links: links}

      state =
        %{
          state
          | active_screensharing:
              if(peer_type == :screensharing, do: peer_pid, else: state.active_screensharing),
            tracks: tracks |> Map.new(&{&1.id, &1}) |> Map.merge(state.tracks)
        }
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
    Membrane.Logger.info("New incoming #{encoding} track: #{track_id}")
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

      state =
        if state.active_screensharing == peer_pid do
          %{state | active_screensharing: nil}
        else
          state
        end

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

  defp new_tracks(:participant) do
    stream_id = Track.stream_id()
    [Track.new(:audio, stream_id), Track.new(:video, stream_id)]
  end

  defp new_tracks(:screensharing) do
    screensharing_id =
      "SCREEN:#{Base.encode16(:crypto.strong_rand_bytes(8))}" |> String.slice(0, 16)

    [Track.new(:video, Track.stream_id(), id: screensharing_id)]
  end

  defp new_peer_links(:participant, endpoint, ctx, state) do
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
  end

  defp new_peer_links(:screensharing, _, _, _) do
    []
  end

  defp parse_stun_servers(""), do: []

  defp parse_stun_servers(servers) do
    servers
    |> String.split(",")
    |> Enum.map(fn server ->
      with [addr, port] <- String.split(server, ":"),
           {port, ""} <- Integer.parse(port) do
        %{server_addr: parse_addr(addr), server_port: port}
      else
        _ -> raise("Bad STUN server format. Expected addr:port, got: #{inspect(server)}")
      end
    end)
  end

  defp parse_turn_servers(""), do: []

  defp parse_turn_servers(servers) do
    servers
    |> String.split(",")
    |> Enum.map(fn server ->
      with [addr, port, username, password, proto] when proto in ["udp", "tcp", "tls"] <-
             String.split(server, ":"),
           {port, ""} <- Integer.parse(port) do
        %{
          server_addr: parse_addr(addr),
          server_port: port,
          username: username,
          password: password,
          proto: String.to_atom(proto)
        }
      else
        _ ->
          raise("""
          "Bad TURN server format. Expected addr:port:username:password:proto, got: \
          #{inspect(server)}
          """)
      end
    end)
  end

  defp parse_addr(addr) do
    case :inet.parse_address(String.to_charlist(addr)) do
      {:ok, ip} -> ip
      # FQDN?
      {:error, :einval} -> addr
    end
  end
end
