defmodule HlsProxyApi.Connection.ConnectionStarter do
  @moduledoc false
  use Task

  require Logger

  alias HlsProxyApi.Connection.ConnectionSupervisor
  alias HlsProxyApi.Streams.Stream

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
        id: "stream",
        stream_url: "rtsp://rtsp.membrane.work:554/testsrc.264",
        token: "path"
      }
    )
  end
end
