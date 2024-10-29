defmodule Membrane.Demo.RtmpToAdaptiveHls do
  use Membrane.Pipeline

  alias Membrane.RTMP.SourceBin

  @segment_duration Membrane.Time.seconds(4)
  @transcode_targets [{720, 60}, {720, 30}, {360, 30}, {180, 30}, {180, 2}]

  @impl true
  def handle_init(_context, %{client_ref: client_ref}) do
    structure = [
      child(:src, %SourceBin{
        client_ref: client_ref,
      }),

      child(:sink, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: :infinity,
        persist?: false,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }),

      get_child(:src)
      |> via_out(:audio)
      |> via_in(Pad.ref(:input, "audio_master"),
        options: [
          encoding: :AAC,
          segment_duration: @segment_duration
        ]
      )
      |> get_child(:sink),

      get_child(:src)
      |> via_out(:video)
      |> child(:tee_video, Membrane.Tee.Parallel)
    ]

    {[spec: structure], %{client_ref: client_ref}}
  end

  @impl true
  def handle_info(%Membrane.RTMP.Messages.SetDataFrame{} = message, _ctx, state) do
    %{height: source_height, width: source_width, framerate: source_framerate} = message
    source_framerate = if source_framerate, do: trunc(source_framerate), else: 60

    spec = @transcode_targets
    |> Enum.filter(fn({target_height, framerate}) ->
      framerate <= source_framerate and target_height <= source_height
    end)
    |> Enum.map(fn({target_height, framerate}) ->
      height = normalize_scale(target_height)
      width = normalize_scale(source_width / (source_height / target_height))
      track_name = "video_#{height}p#{framerate}"

      get_child(:tee_video)
      |> child(%Membrane.H264.Parser{
        output_stream_structure: :annexb,
        generate_best_effort_timestamps: %{framerate: {source_framerate, 1}}
      })
      |> child(Membrane.H264.FFmpeg.Decoder)
      |> child(%Membrane.FramerateConverter{framerate: {framerate, 1}})
      |> child(%Membrane.FFmpeg.SWScale.Scaler{
        output_height: height,
        output_width: width
      })
      |> child(%Membrane.H264.FFmpeg.Encoder{
        preset: :ultrafast,
        gop_size: round(framerate * 2),
      })
      |> via_in(Pad.ref(:input, track_name),
        options: [
          track_name: track_name,
          encoding: :H264,
          segment_duration: @segment_duration
        ]
      )
      |> get_child(:sink)
    end)

    {[spec: spec], state}
  end

  @impl true
  def handle_info( message, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_call(:get_video_id, _ctx, state) do
    {[{:reply, state.video.id}], state}
  end

  defp normalize_scale(scale) when is_float(scale), do:
    scale |> trunc() |> normalize_scale()
  defp normalize_scale(scale) when is_integer(scale) and scale > 0 do
    if rem(scale, 2) == 1, do: scale - 1, else: scale
  end
end
