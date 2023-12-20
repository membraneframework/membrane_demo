require Logger
Logger.configure(level: :info)

Mix.install([
  {:membrane_core, "~> 1.0"},
  {:membrane_udp_plugin, "~> 0.12.0"},
  {:membrane_rtp_plugin, "~> 0.24.0"},
  {:membrane_rtp_aac_plugin, "~> 0.8.0"},
  {:membrane_rtp_h264_plugin, "~> 0.19.0"},
  {:membrane_http_adaptive_stream_plugin, "~> 0.18.0"},
  {:membrane_fake_plugin, "~> 0.11.0"}
])

defmodule RtpToHls do
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_ctx, %{port: port}) do
    spec = [
      child(:app_source, %Membrane.UDP.Source{local_port_no: port})
      |> via_in(Pad.ref(:rtp_input, make_ref()))
      |> child(:rtp, Membrane.RTP.SessionBin),
      child(:hls, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: Membrane.Time.seconds(10),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      })
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, 96, _ext}, :rtp, _ctx, state) do
    spec =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.H264.Depayloader])
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:hls)

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, 127, _ext}, :rtp, _ctx, state) do
    spec =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.AAC.Depayloader])
      |> via_in(Pad.ref(:input, :audio),
        options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:hls)

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, _payload_type, _ext}, :rtp, _ctx, state) do
    Logger.warning("Unsupported stream connected")

    spec =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> child({:fake_sink, ssrc}, Membrane.Fake.Sink.Buffers)

    {[spec: spec], state}
  end

  @impl true
  def handle_child_notification({:track_playable, _track_info}, :hls, _context, state) do
    send(:script, :playlist_ready)
    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _element, _ctx, state) do
    {[], state}
  end
end

File.rm_rf!("output")
File.mkdir!("output")

Process.register(self(), :script)

Logger.info("Starting the pipeline")
input_port = 5000
{:ok, _supervisor, _pipeline} = Membrane.Pipeline.start_link(RtpToHls, %{port: input_port})

if System.get_env("CI") == "true" do
  # Wait to catch potential pipeline setup errors
  Process.sleep(1000)
  Logger.info("CI=true, exiting")
  exit(:normal)
end

Logger.info("Waiting for the RTP stream on port #{input_port}")

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
    server_name: ~c"rtp_to_hls",
    server_root: "/tmp"
  )

Logger.info("Playback available at http://localhost:8000/stream.html")

Process.sleep(:infinity)
