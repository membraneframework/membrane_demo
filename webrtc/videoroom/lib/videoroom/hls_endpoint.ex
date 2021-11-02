defmodule HLS.Endpoint do
  use Membrane.Bin
  import WebRTCToHLS.Helpers

  def_input_pad(:input,
    demand_unit: :buffers,
    caps: :any,
    availability: :on_request,
    options: [
      encoding: [
        spec: :OPUS | :H264,
        description: "Track encoding"
      ],
      track_enabled: [
        spec: boolean(),
        default: true,
        description: "Enable or disable track"
      ]
    ]
  )

  def_options(
    inbound_tracks: [
      spec: [Membrane.WebRTC.Track.t()],
      default: [],
      description: "List of initial inbound tracks"
    ],
    outbound_tracks: [
      spec: [Membrane.WebRTC.Track.t()],
      default: [],
      description: "List of initial outbound tracks"
    ],
    subdirectory_name: [
      spec: String.t(),
      description: "Name of subdirectory after hls_output"
    ]
  )

  def handle_init(opts) do
    state = %{
      tracks: %{},
      stream_ids: MapSet.new(),
      subdirectory_name: opts.subdirectory_name
    }

    {:ok, state}
  end

  @impl true
  def handle_other({:add_tracks, tracks}, _ctx, state) do
    tracks_id_to_link_with_encoding = Enum.map(tracks, fn track -> {track.id, track.encoding} end)

    negotiations = [notify: {:negotiation_done, tracks_id_to_link_with_encoding}]
    new_tracks = Map.new(tracks, &{&1.id, &1})
    {{:ok, negotiations}, Map.update!(state, :tracks, &Map.merge(&1, new_tracks))}
  end

  def handle_notification(_notification, _element, _context, state) do
    {:ok, state}
  end

  def handle_pad_added(Pad.ref(:input, track_id) = pad, ctx, state) do
    options = ctx.pads[pad].options
    link_builder = link_bin_input(pad)
    track = Map.get(state.tracks, track_id)

    directory = hls_output_path(state.subdirectory_name, track.stream_id)

    # remove directory if it already exists
    File.rm_rf(directory)
    File.mkdir_p!(directory)

    spec = hls_links_and_children(link_builder, options.encoding, track_id, track.stream_id)

    {spec, state} =
      if MapSet.member?(state.stream_ids, track.stream_id) do
        {spec, state}
      else
        hls_sink = %Membrane.HTTPAdaptiveStream.Sink{
          manifest_module: Membrane.HTTPAdaptiveStream.HLS,
          target_window_duration: 20 |> Membrane.Time.seconds(),
          target_segment_duration: 2 |> Membrane.Time.seconds(),
          persist?: false,
          storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: directory}
        }

        new_spec = %{
          spec
          | children: Map.put(spec.children, {:hls_sink, track.stream_id}, hls_sink)
        }

        {new_spec, %{state | stream_ids: MapSet.put(state.stream_ids, track.stream_id)}}
      end

    {{:ok, spec: spec}, state}
  end

  defp hls_links_and_children(link_builder, encoding, track_id, stream_id) do
    case encoding do
      :H264 ->
        %ParentSpec{
          children: %{
            {:video_parser, track_id} => %Membrane.H264.FFmpeg.Parser{
              framerate: {30, 1},
              alignment: :au,
              attach_nalus?: true
            },
            {:video_payloader, track_id} => Membrane.MP4.Payloader.H264,
            {:video_cmaf_muxer, track_id} => %Membrane.MP4.CMAF.Muxer{
              segment_duration: 2 |> Membrane.Time.seconds()
            }
          },
          links: [
            link_builder
            |> to({:video_parser, track_id})
            |> to({:video_payloader, track_id})
            |> to({:video_cmaf_muxer, track_id})
            |> via_in(Pad.ref(:input, track_id))
            |> to({:hls_sink, stream_id})
          ]
        }

      :OPUS ->
        %ParentSpec{
          children: %{
            {:opus_decoder, track_id} => Membrane.Opus.Decoder,
            {:aac_encoder, track_id} => Membrane.AAC.FDK.Encoder,
            {:aac_parser, track_id} => %Membrane.AAC.Parser{out_encapsulation: :none},
            {:audio_payloader, track_id} => Membrane.MP4.Payloader.AAC,
            {:audio_cmaf_muxer, track_id} => Membrane.MP4.CMAF.Muxer
          },
          links: [
            link_builder
            |> to({:opus_decoder, track_id})
            |> to({:aac_encoder, track_id})
            |> to({:aac_parser, track_id})
            |> to({:audio_payloader, track_id})
            |> to({:audio_cmaf_muxer, track_id})
            |> via_in(Pad.ref(:input, track_id))
            |> to({:hls_sink, stream_id})
          ]
        }
    end
  end
end
