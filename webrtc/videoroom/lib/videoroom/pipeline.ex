defmodule VideoRoom.Pipeline do
  use Membrane.Pipeline

  alias Membrane.WebRTC.{EndpointBin, Track, Endpoint}
  alias VideoRoom.TrackManager

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

    {:ok,
     %{
       room_id: room_id,
       endpoints: %{},
       track_manager: TrackManager.new(max_display_num: 1),
       active_screensharing: nil
     }}
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
      endpoint = Endpoint.new(tracks)
      endpoint_bin = {:endpoint, peer_pid}

      stun_servers =
        parse_stun_servers(Application.fetch_env!(:membrane_videoroom_demo, :stun_servers))

      turn_servers =
        parse_turn_servers(Application.fetch_env!(:membrane_videoroom_demo, :turn_servers))

      children = %{
        endpoint_bin => %EndpointBin{
          # screensharing type should not receive any streams
          outbound_tracks:
            if(peer_type == :participant, do: get_all_tracks(state.endpoints), else: []),
          inbound_tracks: tracks,
          stun_servers: stun_servers,
          turn_servers: turn_servers,
          handshake_opts: [
            client_mode: false,
            dtls_srtp: true,
            pkey: Application.get_env(:membrane_videoroom_demo, :dtls_pkey),
            cert: Application.get_env(:membrane_videoroom_demo, :dtls_cert)
          ]
        }
      }

      links = new_peer_links(peer_type, endpoint_bin, ctx, state)

      tracks_msgs =
        flat_map_children(ctx, fn
          {:endpoint, other_peer_pid} = endpoint_bin
          when other_peer_pid != state.active_screensharing ->
            [forward: {endpoint_bin, {:add_tracks, tracks}}]

          _child ->
            []
        end)

      spec = %ParentSpec{children: children, links: links}

      state = %{
        state
        | active_screensharing:
            if(peer_type == :screensharing, do: peer_pid, else: state.active_screensharing)
      }

      state = put_in(state.endpoints[peer_pid], endpoint)
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
  def handle_notification({:new_track, track_id, encoding}, endpoint_bin, ctx, state) do
    Membrane.Logger.info("New incoming #{encoding} track #{track_id}")
    {:endpoint, endpoint_id} = endpoint_bin
    {track_enabled, state} = enable_track?(encoding, track_id, endpoint_id, state)
    tee = {:tee, {endpoint_id, track_id}}
    fake = {:fake, {endpoint_id, track_id}}

    children = %{
      tee => Membrane.Element.Tee.Parallel,
      fake => Membrane.Element.Fake.Sink.Buffers
    }

    links =
      [
        link(endpoint_bin)
        |> via_out(Pad.ref(:output, track_id), options: [track_enabled: track_enabled])
        |> to(tee)
        |> to(fake)
      ] ++
        flat_map_children(ctx, fn
          {:endpoint, peer_pid} = other_endpoint
          when endpoint_bin != other_endpoint and peer_pid != state.active_screensharing ->
            [
              link(tee)
              |> via_in(Pad.ref(:input, track_id), options: [encoding: encoding])
              |> to(other_endpoint)
            ]

          _child ->
            []
        end)

    spec = %ParentSpec{children: children, links: links}
    endpoint = Endpoint.update_track(state.endpoints[endpoint_id], track_id, encoding)
    state = put_in(state.endpoints[endpoint_id], endpoint)
    {{:ok, spec: spec}, state}
  end

  def handle_notification(
        {:vad, val} = msg,
        {:endpoint, endpoint_id} = from,
        _ctx,
        state
      ) do
    Membrane.Logger.info("#{inspect(msg)}, from: #{inspect(from)}")

    {actions, state} =
      case TrackManager.update_track(state.track_manager, endpoint_id, val) do
        {:ok, track_manager} ->
          {[], %{state | track_manager: track_manager}}

        {{:replace_track, old_id, new_id}, track_manager} ->
          actions =
            get_disable_track_actions(state.endpoints[old_id], {:endpoint, old_id}) ++
              get_enable_track_actions(state.endpoints[new_id], {:endpoint, new_id})

          {actions, %{state | track_manager: track_manager}}

        {:error, :no_such_track_id} ->
          {[], state}
      end

    {{:ok, actions}, state}
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
      {endpoint, state} = pop_in(state, [:endpoints, peer_pid])

      tracks = Enum.map(Endpoint.get_tracks(endpoint), &%Track{&1 | enabled?: false})

      children =
        Endpoint.get_tracks(endpoint)
        |> Enum.map(fn track -> track.id end)
        |> Enum.flat_map(&[tee: {peer_pid, &1}, fake: {peer_pid, &1}])
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
    if state.endpoints == %{} do
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

  defp new_peer_links(:participant, endpoint_bin, ctx, state) do
    flat_map_children(ctx, fn
      {:tee, {endpoint_id, track_id}} = tee ->
        encoding = Endpoint.get_track_by_id(state.endpoints[endpoint_id], track_id).encoding

        [
          link(tee)
          |> via_in(Pad.ref(:input, track_id),
            options: [encoding: encoding]
          )
          |> to(endpoint_bin)
        ]

      _child ->
        []
    end)
  end

  defp new_peer_links(:screensharing, _endpoint, _ctx, _state) do
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

  defp get_all_tracks(endpoints),
    do: Enum.flat_map(endpoints, fn {_id, endpoint} -> Endpoint.get_tracks(endpoint) end)

  defp get_disable_track_actions(endpoint, endpoint_bin) do
    Enum.map(Endpoint.get_video_tracks(endpoint), fn %Track{id: id} ->
      {:forward, {endpoint_bin, {:disable_track, id}}}
    end)
  end

  defp get_enable_track_actions(endpoint, endpoint_bin) do
    Enum.map(Endpoint.get_video_tracks(endpoint), fn %Track{id: id} ->
      {:forward, {endpoint_bin, {:enable_track, id}}}
    end)
  end

  defp enable_track?(encoding, track_id, endpoint_id, state) do
    cond do
      String.starts_with?(track_id, "SCREEN:") -> {true, state}
      encoding != :OPUS ->
        case TrackManager.add_track(state.track_manager, endpoint_id) do
          {:ok, track_manager} -> {false, %{state | track_manager: track_manager}}
          {{:send_track, _id}, track_manager} -> {true, %{state | track_manager: track_manager}}
        end
      true -> {true, state}
    end
  end
end
