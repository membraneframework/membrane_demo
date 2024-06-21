defmodule Membrane.Demo.RtspToHls.Pipeline do
  @moduledoc """
  The pipeline, which converts the RTP stream to HLS.
  """
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_context, options) do
    Logger.debug("Source handle_init options: #{inspect(options)}")

    spec = [
      child(:source, %Membrane.RTSP.Source{
        transport: {:udp, options.port, options.port + 5},
        allowed_media_types: [:video],
        stream_uri: options.stream_url
      }),
      child(
        :hls,
        %Membrane.HTTPAdaptiveStream.SinkBin{
          target_window_duration: Membrane.Time.seconds(120),
          manifest_module: Membrane.HTTPAdaptiveStream.HLS,
          storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
            directory: options.output_path
          }
        }
      )
    ]

    {[spec: spec],
     %{
       video: nil,
       output_path: options.output_path,
       parent_pid: options.parent_pid,
       rtp_started: false
     }}
  end

  @impl true
  def handle_child_notification(
        {:new_track, ssrc, %{type: :video} = track},
        :source,
        _ctx,
        %{rtp_started: false} = state
      ) do
    Logger.debug(":new_rtp_stream")

    {spss, ppss} =
      case track.fmtp.sprop_parameter_sets do
        nil -> {[], []}
        parameter_sets -> {parameter_sets.sps, parameter_sets.pps}
      end

    structure =
      get_child(:source)
      |> via_out(Pad.ref(:output, ssrc))
      |> child(
        :video_nal_parser,
        %Membrane.H264.Parser{
          spss: spss,
          ppss: ppss,
          generate_best_effort_timestamps: %{framerate: {30, 1}}
        }
      )
      |> via_in(:input, options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)])
      |> get_child(:hls)

    {[spec: structure], %{state | rtp_started: true}}
  end

  @impl true
  def handle_child_notification({:new_track, ssrc, _track}, :source, _ctx, state) do
    Logger.warning("new_rtp_stream Unsupported stream connected")

    structure =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> child({:fake_sink, ssrc}, Membrane.Element.Fake.Sink.Buffers)

    {[spec: structure], state}
  end

  @impl true
  def handle_child_notification({:track_playable, _ref}, :hls, _ctx, state) do
    send(state.parent_pid, :track_playable)
    {[], state}
  end

  @impl true
  def handle_child_notification(notification, element, _ctx, state) do
    Logger.warning("Unknown notification: #{inspect(notification)}, el: #{inspect(element)}")

    {[], state}
  end
end
