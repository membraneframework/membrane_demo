defmodule CameraToHlsNerves.Pipeline do
  use Membrane.Pipeline

  def start_link(opts) do
    Membrane.Pipeline.start_link(__MODULE__, opts)
  end

  @impl true
  def handle_init(_ctx, _opts) do
    spec = [
      child(:source, %Membrane.Rpicam.Source{framerate: {30, 1}})
      |> child(:parser, %Membrane.H264.Parser{generate_best_effort_timestamps: %{framerate: {30, 1}}})
      |> via_in(:input,
        options: [
          encoding: :H264,
          track_name: "my_track",
          segment_duration: Membrane.Time.seconds(5)
        ]
      )
      |> child(:hls_sink, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "/data/output"},
        target_window_duration: Membrane.Time.seconds(10)
      })
    ]

    # Not waiting causes libcamera-vid to crash
    Process.sleep(50)

    {[spec: spec], %{}}
  end
end
