require Logger
Logger.configure(level: :info)

Mix.install([
  {:membrane_core, "~> 1.0"},
  {:membrane_camera_capture_plugin, "~> 0.7.2"},
  {:membrane_ffmpeg_swscale_plugin, "~> 0.15.1"},
  {:membrane_h264_ffmpeg_plugin, "~> 0.31.6"},
  {:membrane_http_adaptive_stream_plugin, "~> 0.18.4"}
])

defmodule CameraToHls do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, _opts) do
    # Captures video from the camera (raw video, depending on camera/os)
    spec =
      child(:source, Membrane.CameraCapture)
      # Converts pixel format to I420 (this is still a raw video)
      |> child(:converter, %Membrane.FFmpeg.SWScale.PixelFormatConverter{format: :I420})
      # Takes raw video in I420 pixel format and encodes it into H264.
      # The baseline profile is usually most suitable for live streaming
      |> child(:encoder, %Membrane.H264.FFmpeg.Encoder{profile: :baseline})
      # Muxes H264 into CMAF (short, mp4-like chunks) and generates
      # an HLS playlist.
      |> via_in(:input,
        options: [
          encoding: :H264,
          track_name: "my_track",
          segment_duration: Membrane.Time.seconds(5)
        ]
      )
      |> child(:hls_sink, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"},
        target_window_duration: Membrane.Time.seconds(10)
      })

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:track_playable, _track_info}, :hls_sink, _context, state) do
    send(:script, :playlist_ready)
    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _context, state) do
    {[], state}
  end
end

# On CI we just check if the script compiles
if System.get_env("CI") == "true" do
  Logger.info("CI=true, exiting")
  exit(:normal)
end

File.rm_rf!("output")
File.mkdir!("output")

Process.register(self(), :script)

Logger.info("Starting the pipeline")
{:ok, _supervisor, _pipeline} = Membrane.Pipeline.start_link(CameraToHls)

Logger.info("Waiting for the playlist to be ready")

receive do
  :playlist_ready -> :ok
end

Logger.info("Starting HTTP server")
:ok = :inets.start()

{:ok, _server} =
  :inets.start(:httpd,
    bind_address: ~c"localhost",
    port: 8000,
    document_root: ~c".",
    server_name: ~c"camera_to_hls",
    server_root: "/tmp"
  )

Logger.info("Playback available at http://localhost:8000/stream.html")

Process.sleep(:infinity)
