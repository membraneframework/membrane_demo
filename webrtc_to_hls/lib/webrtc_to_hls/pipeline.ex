defmodule WebRTCToHLS.Pipeline do
  use Membrane.Pipeline
  import Membrane.RTC.Utils

  alias Membrane.WebRTC.{Endpoint, EndpointBin, Track}
  alias Membrane.RTC.Engine.MediaEvent

  require Membrane.Logger

  import WebRTCToHLS.Helpers

  @registry_name WebRTCToHLS.Registry

  @type stun_server_t() :: ExLibnice.stun_server()
  @type turn_server_t() :: ExLibnice.relay_info()

  @type extension_options_t() :: [
          vad: boolean()
        ]

  @type packet_filters_t() :: %{
          (encoding_name :: atom()) => [Membrane.RTP.SessionBin.packet_filter_t()]
        }

  @type network_options_t() :: [
          stun_servers: [stun_server_t()],
          turn_servers: [turn_server_t()],
          dtls_pkey: binary(),
          dtls_cert: binary()
        ]

  @type options_t() :: [
          id: String.t(),
          extension_options: extension_options_t(),
          network_options: network_options_t(),
          packet_filters: %{
            (encoding_name :: atom()) => [packet_filters_t()]
          }
        ]

  @spec start(options :: options_t(), process_options :: GenServer.options()) ::
          GenServer.on_start()
  def start(options, process_options) do
    do_start(:start, options, process_options)
  end

  @spec start_link(options :: options_t(), process_options :: GenServer.options()) ::
          GenServer.on_start()
  def start_link(options, process_options) do
    do_start(:start_link, options, process_options)
  end

  defp do_start(func, options, process_options) when func in [:start, :start_link] do
    id = options[:id] || "#{UUID.uuid4()}"
    options = Keyword.put(options, :id, id)

    Membrane.Logger.info("Starting a new SFU instance with id: #{id}")

    apply(Membrane.Pipeline, func, [
      __MODULE__,
      options,
      process_options
    ])
  end

  @spec get_registry_name() :: atom()
  def get_registry_name(), do: @registry_name

  @impl true
  def handle_init(options) do
    play(self())

    {{:ok, log_metadata: [sfu: options[:id]]},
     %{
       id: options[:id],
       peers: %{},
       endpoints: %{},
       options: options,
       packet_filters: options[:packet_filters] || %{},
       waiting_for_linking: %{}
     }}
  end

  @impl true
  def handle_other({:register, pid}, _ctx, state) do
    Registry.register(get_registry_name(), self(), pid)
    {:ok, state}
  end

  @impl true
  def handle_other({:unregister, pid}, _ctx, state) do
    Registry.unregister_match(get_registry_name(), self(), pid)
    {:ok, state}
  end

  @impl true
  def handle_other({:remove_peer, _id}, _ctx, state) do
    # pipeline supports just a single peer, it will be closed when peer's
    # process stops
    {:ok, state}
  end

  @impl true
  def handle_other({:media_event, from, data}, ctx, state) do
    case MediaEvent.deserialize(data) do
      {:ok, event} ->
        if event.type == :join or Map.has_key?(state.peers, from) do
          {actions, state} = handle_media_event(event, from, ctx, state)
          {{:ok, actions}, state}
        else
          Membrane.Logger.warn("Received media event from unknown peer id: #{inspect(from)}")
          {:ok, state}
        end

      {:error, :invalid_media_event} ->
        Membrane.Logger.warn("Invalid media event #{inspect(data)}")
        {:ok, state}
    end
  end

  defp handle_media_event(%{type: :join, data: data}, peer_id, ctx, state) do
    dispatch({:new_peer, peer_id, data.metadata})

    receive do
      {:accept_new_peer, ^peer_id} ->
        do_accept_new_peer(peer_id, node(), data, ctx, state)

      {:accept_new_peer, ^peer_id, peer_node} ->
        do_accept_new_peer(peer_id, peer_node, data, ctx, state)

      {:accept_new_peer, peer_id} ->
        Membrane.Logger.warn("Unknown peer id passed for acceptance: #{inspect(peer_id)}")
        {[], state}

      {:accept_new_peer, peer_id, peer_node} ->
        Membrane.Logger.warn(
          "Unknown peer id passed for acceptance: #{inspect(peer_id)} for node #{inspect(peer_node)}"
        )

        {[], state}

      {:deny_new_peer, peer_id} ->
        MediaEvent.create_peer_denied_event(peer_id)
        |> dispatch()

        {[], state}

      {:deny_new_peer, peer_id, data: data} ->
        MediaEvent.create_peer_denied_event(peer_id, data)
        |> dispatch()

        {[], state}
    end
  end

  defp handle_media_event(%{type: :sdp_offer} = event, peer_id, _ctx, state) do
    actions = [
      forward:
        {{:endpoint, peer_id},
         {:signal, {:sdp_offer, event.data.sdp_offer.sdp, event.data.mid_to_track_id}}}
    ]

    peer = get_in(state, [:peers, peer_id])
    peer = Map.put(peer, :track_id_to_track_metadata, event.data.track_id_to_track_metadata)
    state = put_in(state, [:peers, peer_id], peer)

    {actions, state}
  end

  defp handle_media_event(%{type: :candidate} = event, peer_id, _ctx, state) do
    actions = [forward: {{:endpoint, peer_id}, {:signal, {:candidate, event.data.candidate}}}]
    {actions, state}
  end

  defp handle_media_event(%{type: :leave}, _peer_id, _ctx, state) do
    # pipeline is handling just a single peer, do nothing as once peer's process stops
    # the pipeline will be automatically closed
    {[], state}
  end

  defp handle_media_event(%{type: :renegotiate_tracks}, peer_id, _ctx, state) do
    actions = [forward: {{:endpoint, peer_id}, {:signal, :renegotiate_tracks}}]
    {actions, state}
  end

  @impl true
  def handle_notification(
        {:signal, {:sdp_answer, answer, mid_to_track_id}},
        {:endpoint, peer_id},
        _ctx,
        state
      ) do
    MediaEvent.create_signal_event(peer_id, {:signal, {:sdp_answer, answer, mid_to_track_id}})
    |> dispatch()

    {:ok, state}
  end

  @impl true
  def handle_notification({:signal, message}, {:endpoint, peer_id}, _ctx, state) do
    MediaEvent.create_signal_event(peer_id, {:signal, message})
    |> dispatch()

    {:ok, state}
  end

  @impl true
  def handle_notification({:new_track, track_id, encoding}, endpoint_bin_name, _ctx, state) do
    Membrane.Logger.info(
      "New incoming #{encoding} track #{track_id} from #{inspect(endpoint_bin_name)}"
    )

    {:endpoint, endpoint_id} = endpoint_bin_name

    extensions = setup_extensions(encoding, state[:options][:extension_options])

    link_builder =
      link(endpoint_bin_name)
      |> via_out(Pad.ref(:output, track_id), options: [extensions: extensions])

    %{children: hls_children, links: hls_links} =
      hls_links_and_children(link_builder, encoding, track_id)

    spec = %ParentSpec{
      children: hls_children,
      links: hls_links,
      crash_group: {endpoint_id, :temporary}
    }

    state =
      update_in(
        state,
        [:endpoints, endpoint_id],
        &Endpoint.update_track_encoding(&1, track_id, encoding)
      )

    {{:ok, spec: spec}, state}
  end

  def handle_notification({:vad, val}, {:endpoint, endpoint_id}, _ctx, state) do
    dispatch({:vad_notification, val, endpoint_id})
    {:ok, state}
  end

  def handle_notification({:track_playable, {content_type, _track_id}}, :hls_bin, _ctx, state) do
    # notify about playable just when video becomes available
    if content_type == :video do
      dispatch({:playlist_playable, self() |> pid_hash()}, state)
    end

    {:ok, state}
  end

  # the peer has left, ignore the notification as the pipeline is closing on its own
  def handle_notification({:end_of_stream, :input}, {:aac_encoder, _}, _ctx, state) do
    {:ok, state}
  end

  def handle_notification(:end_of_stream, :hls_bin, _ctx, state) do
    {:ok, state}
  end

  def handle_notification({:cleanup, fun}, :hls_bin, _ctx, state) do
    fun.()
    {:ok, state}
  end

  defp dispatch(msg, _state) do
    Registry.dispatch(get_registry_name(), self(), fn entries ->
      for {_, pid} <- entries, do: send(pid, {self(), msg})
    end)
  end

  @impl true
  def handle_notification(
        {:negotiation_done, new_outbound_tracks},
        {:endpoint, endpoint_id},
        ctx,
        state
      ) do
    {new_links, new_waiting_for_linking} =
      link_outbound_tracks(new_outbound_tracks, endpoint_id, ctx)

    state =
      update_in(
        state,
        [:waiting_for_linking, endpoint_id],
        &MapSet.union(&1, new_waiting_for_linking)
      )

    {{:ok, [spec: %ParentSpec{links: new_links}]}, state}
  end

  @impl true
  def handle_notification({:new_tracks, tracks}, {:endpoint, endpoint_id}, ctx, state) do
    id_to_track = Map.new(tracks, &{&1.id, &1})

    state =
      update_in(state, [:endpoints, endpoint_id, :inbound_tracks], &Map.merge(&1, id_to_track))

    tracks_msgs = update_track_messages(ctx, {:add_tracks, tracks}, {:endpoint, endpoint_id})

    peer = get_in(state, [:peers, endpoint_id])

    MediaEvent.create_tracks_added_event(endpoint_id, peer.track_id_to_track_metadata)
    |> dispatch()

    {{:ok, tracks_msgs}, state}
  end

  @impl true
  def handle_notification({:removed_tracks, tracks}, {:endpoint, endpoint_id}, ctx, state) do
    id_to_track = Map.new(tracks, &{&1.id, &1})

    state =
      update_in(state, [:endpoints, endpoint_id, :inbound_tracks], &Map.merge(&1, id_to_track))

    tracks_msgs = update_track_messages(ctx, {:remove_tracks, tracks}, {:endpoint, endpoint_id})
    track_ids = Enum.map(tracks, & &1.id)

    MediaEvent.create_tracks_removed_event(endpoint_id, track_ids)
    |> dispatch()

    {{:ok, tracks_msgs}, state}
  end

  defp link_outbound_tracks(tracks, endpoint_id, ctx) do
    Enum.reduce(tracks, {[], MapSet.new()}, fn
      {track_id, encoding}, {new_links, not_linked} ->
        tee = find_child(ctx, pattern: {:tee, {_other_endpoint_id, ^track_id}})

        if tee do
          new_link =
            link(tee)
            |> via_out(:copy)
            |> via_in(Pad.ref(:input, track_id), options: [encoding: encoding])
            |> to({:endpoint, endpoint_id})

          {new_links ++ [new_link], not_linked}
        else
          {new_links, MapSet.put(not_linked, track_id)}
        end

      _track, {new_links, not_linked} ->
        {new_links, not_linked}
    end)
  end

  defp dispatch(msg) do
    Registry.dispatch(get_registry_name(), self(), fn entries ->
      for {_, pid} <- entries, do: send(pid, {self(), msg})
    end)
  end

  defp do_accept_new_peer(peer_id, peer_node, data, ctx, state) do
    if Map.has_key?(state.peers, peer_id) do
      Membrane.Logger.warn("Peer with id: #{inspect(peer_id)} has already been added")
      {[], state}
    else
      peer =
        if Map.has_key?(data, :track_id_to_track_metadata),
          do: data,
          else: Map.put(data, :track_id_to_track_metadata, %{})

      peer = Map.put(peer, :id, peer_id)

      state = put_in(state, [:peers, peer_id], peer)
      {actions, state} = setup_peer(peer, peer_node, ctx, state)

      MediaEvent.create_peer_accepted_event(peer_id, Map.delete(state.peers, peer_id))
      |> dispatch()

      MediaEvent.create_peer_joined_event(peer_id, peer) |> dispatch()

      {actions, state}
    end
  end

  defp setup_peer(config, peer_node, _ctx, state) do
    inbound_tracks = []
    outbound_tracks = get_outbound_tracks(state.endpoints, config.receive_media)

    # FIXME `type` field should probably be deleted from Endpoint struct
    endpoint =
      Endpoint.new(config.id, :participant, inbound_tracks, %{receive_media: config.receive_media})

    endpoint_bin_name = {:endpoint, config.id}

    handshake_opts =
      if state.options[:network_options][:dtls_pkey] &&
           state.options[:network_options][:dtls_cert] do
        [
          client_mode: false,
          dtls_srtp: true,
          pkey: state.options[:network_options][:dtls_pkey],
          cert: state.options[:network_options][:dtls_cert]
        ]
      else
        [
          client_mode: false,
          dtls_srtp: true
        ]
      end

    directory =
      self()
      |> pid_hash()
      |> hls_output_path()

    # remove directory if it already exists
    File.rm_rf(directory)
    File.mkdir_p!(directory)

    children = %{
      endpoint_bin_name => %EndpointBin{
        outbound_tracks: outbound_tracks,
        inbound_tracks: inbound_tracks,
        stun_servers: state.options[:network_options][:stun_servers] || [],
        turn_servers: state.options[:network_options][:turn_servers] || [],
        filter_codecs: fn {rtp, fmtp} ->
          case rtp.encoding do
            "opus" -> true
            "VP8" -> false
            "H264" -> fmtp.profile_level_id === 0x42E01F
            _unsupported_codec -> false
          end
        end,
        handshake_opts: handshake_opts,
        log_metadata: [peer_id: config.id]
      },
      hls_bin: %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 20 |> Membrane.Time.seconds(),
        target_segment_duration: 2 |> Membrane.Time.seconds(),
        persist?: false,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: directory}
      }
    }

    state = put_in(state, [:waiting_for_linking, config.id], MapSet.new())

    spec = %ParentSpec{
      node: peer_node,
      children: children,
      crash_group: {config.id, :temporary}
    }

    state = put_in(state.endpoints[config.id], endpoint)

    {[spec: spec], state}
  end

  defp get_outbound_tracks(endpoints, true) do
    Enum.flat_map(endpoints, fn {_id, endpoint} -> Endpoint.get_tracks(endpoint) end)
  end

  defp get_outbound_tracks(_endpoints, false), do: []

  defp hls_links_and_children(link_builder, encoding, track_id) do
    case encoding do
      :H264 ->
        %{
          children: %{
            {:video_parser, track_id} => %Membrane.H264.FFmpeg.Parser{
              framerate: {30, 1},
              alignment: :au,
              attach_nalus?: true
            }
          },
          links: [
            link_builder
            |> to({:video_parser, track_id})
            |> via_in(Pad.ref(:input, {:video, track_id}), options: [encoding: :H264])
            |> to(:hls_bin)
          ]
        }

      :OPUS ->
        %{
          children: %{
            {:opus_decoder, track_id} => Membrane.Opus.Decoder,
            {:aac_encoder, track_id} => Membrane.AAC.FDK.Encoder,
            {:aac_parser, track_id} => %Membrane.AAC.Parser{out_encapsulation: :none}
          },
          links: [
            link_builder
            |> to({:opus_decoder, track_id})
            |> to({:aac_encoder, track_id})
            |> to({:aac_parser, track_id})
            |> via_in(Pad.ref(:input, {:audio, track_id}), options: [encoding: :AAC])
            |> to(:hls_bin)
          ]
        }
    end
  end

  defp setup_extensions(encoding, extension_options) do
    if encoding == :OPUS and extension_options[:vad], do: [{:vad, Membrane.RTP.VAD}], else: []
  end

  defp remove_peer(peer_id, ctx, state) do
    case do_remove_peer(peer_id, ctx, state) do
      {:absent, [], state} ->
        Membrane.Logger.info("Peer #{inspect(peer_id)} already removed")
        {[], state}

      {:present, actions, state} ->
        {_waiting, state} = pop_in(state, [:waiting_for_linking, peer_id])

        MediaEvent.create_peer_left_event(peer_id)
        |> dispatch()

        {actions, state}
    end
  end

  defp do_remove_peer(peer_id, ctx, state) do
    if Map.has_key?(state.endpoints, peer_id) do
      {endpoint, state} = pop_in(state, [:endpoints, peer_id])
      {_peer, state} = pop_in(state, [:peers, peer_id])
      tracks = Enum.map(Endpoint.get_tracks(endpoint), &%Track{&1 | status: :disabled})

      tracks_msgs = update_track_messages(ctx, {:remove_tracks, tracks}, {:endpoint, peer_id})

      endpoint_bin = ctx.children[{:endpoint, peer_id}]

      actions =
        if endpoint_bin == nil or endpoint_bin.terminating? do
          []
        else
          children =
            Endpoint.get_tracks(endpoint)
            |> Enum.map(fn track -> track.id end)
            |> Enum.flat_map(&[tee: {peer_id, &1}, fake: {peer_id, &1}])
            |> Enum.filter(&Map.has_key?(ctx.children, &1))

          children = [endpoint: peer_id] ++ children
          [remove_child: children]
        end

      {:present, tracks_msgs ++ actions, state}
    else
      {:absent, [], state}
    end
  end

  defp update_track_messages(_ctx, [] = _tracks, _endpoint_bin), do: []

  defp update_track_messages(ctx, msg, endpoint_bin_name) do
    flat_map_children(ctx, fn
      {:endpoint, _endpoint_id} = other_endpoint_bin
      when other_endpoint_bin != endpoint_bin_name ->
        [forward: {other_endpoint_bin, msg}]

      _child ->
        []
    end)
  end
end
