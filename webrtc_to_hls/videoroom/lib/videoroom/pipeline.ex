defmodule VideoRoom.Pipeline do
  use Membrane.Pipeline

  alias Membrane.WebRTC.{EndpointBin, Track}

  require Membrane.Logger

  def start_link() do
    Membrane.Pipeline.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def handle_init(_opts) do
    play(self())
    {:ok, %{tracks: %{}, endpoints_tacks_ids: %{}}}
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
        },
        {:hls, peer_pid} => %Membrane.HTTPAdaptiveStream.Sink{
          manifest_module: Membrane.HTTPAdaptiveStream.HLS,
          target_window_duration: 10 |> Membrane.Time.seconds(),
          # storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output/#{pid_to_hash(peer_pid)}"}
          storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output/"}
        },
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
        |> put_in([:endpoints_tacks_ids, peer_pid], Enum.map(tracks, & &1.id))

      {{:ok, [spec: spec] ++ tracks_msgs}, state}
    end
  end

  @impl true
  def handle_other({:signal, peer_pid, msg}, _ctx, state) do
    {{:ok, forward: {{:endpoint, peer_pid}, {:signal, msg}}}, state}
  end

  @impl true
  def handle_other({:remove_peer, peer_pid}, ctx, state) do
    case maybe_remove_peer(peer_pid, ctx, state) do
      {:absent, [], state} ->
        Membrane.Logger.info("Peer #{inspect(peer_pid)} already removed")
        {:ok, state}

      {:present, actions, state} ->
        {{:ok, actions}, state}
    end
  end

  @impl true
  def handle_other({:DOWN, _ref, :process, pid, _reason}, ctx, state) do
    {_status, actions, state} = maybe_remove_peer(pid, ctx, state)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_notification({:new_track, track_id, encoding}, endpoint, ctx, state) do
    Membrane.Logger.info("New incoming #{encoding} track")
    tee = {:tee, track_id}
    fake = {:fake, track_id}

    {:endpoint, peer_pid} = endpoint

    children = %{
      tee => Membrane.Element.Tee.Parallel,
      fake => Membrane.Element.Fake.Sink.Buffers,
    }

    %{children: hls_children, links: hls_links} =
      case encoding do
        :H264 ->
            %{
              children: %{
                video_parser: %Membrane.H264.FFmpeg.Parser{
                  framerate: {30, 1},
                  alignment: :au,
                  attach_nalus?: true
                },
                video_payloader: Membrane.MP4.Payloader.H264,
                video_cmaf_muxer: Membrane.MP4.CMAF.Muxer
              },
              links: [
                link(tee)
                |> to(:video_parser)
                |> to(:video_payloader)
                |> to(:video_cmaf_muxer)
                |> via_in(:input)
                |> to({:hls, peer_pid})
              ]
          }

        :OPUS -> %{
          children: %{
            # opus_parser: Membrane.Opus.Parser,
            # opus_decoder: Membrane.Opus.Decoder,
            # aac_encoder: Membrane.AAC.FDK.Encoder,
            # audio_payloader: Membrane.MP4.Payloader.AAC,
            # audio_cmaf_muxer: Membrane.MP4.CMAF.Muxer
          },
           links: [
            #  link(tee)
            #  |> to(:opus_parser)
            #  |> to(:opus_decoder)
            #  |> to(:aac_encoder)
            #  |> to(:audio_payloader)
            #  |> to(:audio_cmaf_muxer)
            #  |> via_in(:input)
            #  |> to({:hls, peer_pid})
          ]
        }
      end



    links =
      [link(endpoint) |> via_out(Pad.ref(:output, track_id)) |> to(tee) |> to(fake) | hls_links] ++
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

    spec = %ParentSpec{children: Map.merge(children, hls_children), links: links}
    state = update_in(state, [:tracks, track_id], &%Track{&1 | encoding: encoding})
    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:signal, message}, {:endpoint, peer_pid}, _ctx, state) do
    send(peer_pid, {:signal, message})
    {:ok, state}
  end

  def handle_notification({:track_playable, _ref}, _el, _ctx, state) do
    {:ok, state}
  end

  defp maybe_remove_peer(peer_pid, ctx, state) do
    endpoint = ctx.children[{:endpoint, peer_pid}]

    if endpoint == nil or endpoint.terminating? do
      {:absent, [], state}
    else
      {tracks_ids, state} = pop_in(state, [:endpoints_tacks_ids, peer_pid])

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

  defp flat_map_children(ctx, fun) do
    ctx.children |> Map.keys() |> Enum.flat_map(fun)
  end

  defp pid_to_hash(pid) do
    :crypto.hash(:md5, :erlang.pid_to_list(pid)) |> Base.encode16(case: :lower)
  end
end
