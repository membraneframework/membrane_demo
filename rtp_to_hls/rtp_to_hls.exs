require Logger
Logger.configure(level: :info)

Mix.install([
  {:membrane_core, "~> 1.0"},
  {:membrane_udp_plugin, "~> 0.13.0"},
  {:membrane_rtp_plugin, "~> 0.31.0"},
  {:membrane_rtp_h264_plugin, "~> 0.20.0"},
  {:membrane_rtp_aac_plugin, "~> 0.9.1"},
  {:membrane_aac_plugin, "~> 0.19.1"},
  {:membrane_http_adaptive_stream_plugin, "~> 0.18.4"},
  {:membrane_fake_plugin, "~> 0.11.0"},
  {:membrane_h26x_plugin, "~> 0.10.0"}
])

defmodule RTPToHLS do
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_ctx, %{port: port}) do
    spec = [
      child(:app_source, %Membrane.UDP.Source{local_port_no: port})
      |> child(:rtp_demuxer, Membrane.RTP.Demuxer)
      |> via_out(:output, options: [stream_id: {:payload_type, 96}])
      |> child(:rtp_h264_depayloader, Membrane.RTP.H264.Depayloader)
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> child(:hls, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: Membrane.Time.seconds(15),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }),
      get_child(:rtp_demuxer)
      |> via_out(:output, options: [stream_id: {:payload_type, 127}])
      |> child(:rtp_aac_depayloader, %Membrane.RTP.AAC.Depayloader{mode: :hbr})
      |> child(:aac_parser, %Membrane.AAC.Parser{
        audio_specific_config: Base.decode16!("1210"),
        out_encapsulation: :none
      })
      |> via_in(Pad.ref(:input, :audio),
        options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:hls)
    ]

    {[spec: spec], %{}}
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
{:ok, _supervisor, _pipeline} = Membrane.Pipeline.start_link(RTPToHLS, %{port: input_port})

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
