defmodule Membrane.Demo.RtspToHls.Application do
  @moduledoc false
  use Application

  require Logger
  alias Membrane.Demo.RtspToHls.Pipeline

  @rtsp_stream_url "rtsp://ktiv~ProspectHill:ktivHD4@gray.videstra.net:42554/ProspectHill"
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

    {:ok, _sup, pid} = Pipeline.start_link(pipeline_options)
    {:ok, pid}
  end
end
