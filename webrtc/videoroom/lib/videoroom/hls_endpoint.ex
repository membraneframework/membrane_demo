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
    ]
  )

  def handle_init(opts) do
    directory =
      self()
      |> pid_hash()
      |> hls_output_path()

    # remove directory if it already exists
    File.rm_rf(directory)
    File.mkdir_p!(directory)

    sink = %Membrane.HTTPAdaptiveStream.Sink{
      manifest_module: Membrane.HTTPAdaptiveStream.HLS,
      target_window_duration: 20 |> Membrane.Time.seconds(),
      target_segment_duration: 2 |> Membrane.Time.seconds(),
      persist?: false,
      storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: directory}
    }

    spec = %ParentSpec{
      children: %{hls_sink: sink}
    }

    {{:ok, spec: spec}, %{}}
  end

  @impl true
  def handle_other({:add_tracks, tracks}, _ctx, state) do
    tracks_id_to_link_with_encoding = Enum.map(tracks, fn track -> {track.id, track.encoding} end)

    negotiations = [notify: {:negotiation_done, tracks_id_to_link_with_encoding}]
    {{:ok, negotiations}, state}
  end

  def handle_notification(_notification, _element, _context, state) do
    {:ok, state}
  end

  def handle_pad_added(pad, ctx, state) do
    options = ctx.pads[pad].options
    link_builder = link_bin_input(pad)
    spec = hls_links_and_children(link_builder, options.encoding)
    {{:ok, spec: spec}, state}
  end

  defp hls_links_and_children(link_builder, encoding) do
    case encoding do
      :H264 ->
        %ParentSpec{
          children: %{
            video_parser: %Membrane.H264.FFmpeg.Parser{
              framerate: {30, 1},
              alignment: :au,
              attach_nalus?: true
            },
            video_payloader: Membrane.MP4.Payloader.H264,
            video_cmaf_muxer: %Membrane.MP4.CMAF.Muxer{
              segment_duration: 2 |> Membrane.Time.seconds()
            }
          },
          links: [
            link_builder
            |> to(:video_parser)
            |> to(:video_payloader)
            |> to(:video_cmaf_muxer)
            |> via_in(Pad.ref(:input, :video))
            |> to(:hls_sink)
          ]
        }

      :OPUS ->
        %ParentSpec{
          children: %{
            opus_decoder: Membrane.Opus.Decoder,
            aac_encoder: Membrane.AAC.FDK.Encoder,
            aac_parser: %Membrane.AAC.Parser{out_encapsulation: :none},
            audio_payloader: Membrane.MP4.Payloader.AAC,
            audio_cmaf_muxer: Membrane.MP4.CMAF.Muxer
          },
          links: [
            link_builder
            |> to(:opus_decoder)
            |> to(:aac_encoder)
            |> to(:aac_parser)
            |> to(:audio_payloader)
            |> to(:audio_cmaf_muxer)
            |> via_in(Pad.ref(:input, :audio))
            |> to(:hls_sink)
          ]
        }
    end
  end
end
