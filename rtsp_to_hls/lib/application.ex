defmodule Membrane.Demo.RtspToHls.Application do
  @moduledoc false
  use Application

  require Logger
  alias Membrane.Demo.RtspToHls.Pipeline

  @rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"
  @output_path "hls_output"
  @rtp_port 20000

  @impl true
  def start(_type, _args) do
    Logger.debug("Application is starting")

    # Create directory for hls output files
    File.mkdir_p(@output_path)

    pipeline_options = %{
      port: @rtp_port,
      output_path: @output_path,
      stream_url: @rtsp_stream_url
    }

    {:ok, pid} = Pipeline.start_link(pipeline_options)
    Membrane.Pipeline.play(pid)

    {:ok, pid}
  end
end
