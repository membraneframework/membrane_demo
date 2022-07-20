defmodule HlsProxyApi.Connection.ConnectionStarter do
  @moduledoc """
  A module responsible for initializing the RTSP connection.
  """
  use Task

  require Logger

  alias HlsProxyApi.Connection.ConnectionSupervisor
  alias HlsProxyApi.Streams.Stream

  @rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"

  @spec start_link(Keyword.t()) :: {:ok, pid()}
  def start_link(_args) do
    Task.start_link(__MODULE__, :run, [])
  end

  @spec run :: Supervisor.on_start_child()
  def run() do
    Logger.debug("ConnectionStarter: Initializing")

    File.rm_rf(Application.fetch_env!(:hls_proxy_api, :output_dir))

    ConnectionSupervisor.start_stream(
      ConnectionSupervisor,
      %Stream{
        stream_url: @rtsp_stream_url,
        path: Application.fetch_env!(:hls_proxy_api, :hls_path)
      }
    )
  end
end