defmodule CameraToHlsNerves.Pipeline do
  use Membrane.Pipeline

  def start_link(opts) do
    Membrane.Pipeline.start_link(__MODULE__, opts)
  end

  @impl true
  def handle_init(_ctx, _opts) do

    spec = [
      child(:source, Membrane.Rpicam.Source)
      |> child(:parser, Membrane.H264.Parser)
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

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:track_playable, _track_info}, :hls_sink, _context, state) do
    send(:hls_server, :playlist_ready)
    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _context, state) do
    {[], state}
  end
end
