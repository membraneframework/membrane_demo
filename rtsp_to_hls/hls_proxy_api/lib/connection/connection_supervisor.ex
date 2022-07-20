defmodule HlsProxyApi.Connection.ConnectionSupervisor do
  @moduledoc false
  use Supervisor

  require Logger

  alias HlsProxyApi.Connection.ConnectionManager
  alias HlsProxyApi.Stream

  @rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(_args) do
    Supervisor.start_link(
      __MODULE__,
      %Stream{
        stream_url: @rtsp_stream_url,
        path: Application.fetch_env!(:hls_proxy_api, :hls_path)
      },
      name: __MODULE__
    )
  end

  @impl true
  def init(stream) do
    Logger.debug("ConnectionSupervisor: Initializing")

    File.rm_rf(Application.fetch_env!(:hls_proxy_api, :output_dir))

    children = [
      %{
        id: "ConnectionManager",
        start: {ConnectionManager, :start_link, [stream]},
        restart: :transient
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
