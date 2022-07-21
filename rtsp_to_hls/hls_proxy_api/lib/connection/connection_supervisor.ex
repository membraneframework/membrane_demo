defmodule HlsProxyApi.Connection.ConnectionSupervisor do
  @moduledoc false
  use Supervisor

  require Logger

  alias HlsProxyApi.Connection.ConnectionManager
  alias HlsProxyApi.Stream

  @rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(pipeline: pipeline) do
    Logger.debug("Connection supervisor start_link")

    Supervisor.start_link(
      __MODULE__,
      [
        stream: %Stream{
          stream_url: @rtsp_stream_url,
          path: Application.fetch_env!(:hls_proxy_api, :hls_path)
        },
        pipeline: pipeline
      ],
      name: __MODULE__
    )
  end

  @impl true
  def init(args) do
    Logger.debug("ConnectionSupervisor: Initializing, args: #{inspect(args)}")

    children = [
      %{
        id: "ConnectionManager",
        start: {ConnectionManager, :start_link, [args]},
        restart: :transient
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
