defmodule HlsProxyApi.Application do
  @moduledoc false
  use Application

  require Logger

  alias HlsProxyApi.Pipelines.RtpToHls
  alias HlsProxyApi.Stream

  @rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"

  @impl true
  def start(_type, _args) do
    Logger.debug("Application is starting")

    stream = %Stream{
      stream_url: @rtsp_stream_url,
      path: Application.fetch_env!(:hls_proxy_api, :hls_path)
    }

    pipeline_options = [
      port: System.get_env("UDP_PORT") |> String.to_integer(),
      output_path: get_output_path(stream.path)
    ]

    prepare_directory(pipeline_options[:output_path])

    {:ok, pid} = RtpToHls.start_link(pipeline_options)
    Membrane.Pipeline.play(pid)

    {:ok, pid}
  end

  defp get_output_path(hls_path) do
    directory_path = Application.fetch_env!(:hls_proxy_api, :output_dir)
    Path.join(directory_path, hls_path)
  end

  defp prepare_directory(output_path) do
    File.mkdir_p(output_path)
  end
end
