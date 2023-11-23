alias Membrane.Demo.RtspToHls.Pipeline

rtsp_stream_url = "rtsp://localhost:8554/livestream"
output_path = "hls_output"
rtp_port = 20000

# Create directory for hls output files
File.mkdir_p(output_path)

pipeline_options = %{
  port: rtp_port,
  output_path: output_path,
  stream_url: rtsp_stream_url
}

{:ok, _sup, pid} = Membrane.Pipeline.start(Pipeline, pipeline_options)

Process.monitor(pid)

receive do
  {:DOWN, _ref, :process, _pid, _reason} -> :ok
end
