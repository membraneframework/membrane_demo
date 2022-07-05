defmodule HlsProxyApi.Connection.RtspKeepAlive do
  @moduledoc """
  This module is responsible for maintaining the RTSP connection.
  """
  use GenServer

  require Logger

  alias Membrane.RTSP

  @keep_alive_interval 15_000

  @spec start(pid()) :: GenServer.on_start()
  def start(session) do
    GenServer.start(__MODULE__, session)
  end

  @impl true
  def init(session) do
    Process.send_after(self(), :ping, @keep_alive_interva)
    {:ok, session}
  end

  @impl true
  def handle_info(:ping, session) do
    with {:ok, %RTSP.Response{status: 200}} <- RTSP.get_parameter(session) do
      Process.send_after(self(), :ping, @keep_alive_interva)
      {:noreply, session}
    else
      error ->
        Logger.warn("RTSP ping failed: #{inspect(error)}")
        {:stop, session, :request_failed}
    end
  end
end
