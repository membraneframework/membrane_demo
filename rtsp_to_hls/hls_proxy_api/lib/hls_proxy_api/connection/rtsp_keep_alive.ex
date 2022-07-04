defmodule HlsProxyApi.Connection.RtspKeepAlive do
  @moduledoc false
  use GenServer

  require Logger

  alias Membrane.RTSP

  @spec start(pid()) :: GenServer.on_start()
  def start(session) do
    GenServer.start(__MODULE__, session)
  end

  @impl true
  def init(session) do
    Process.send_after(self(), :ping, 15_000)
    {:ok, session}
  end

  @impl true
  def handle_info(:ping, session) do
    with {:ok, %RTSP.Response{status: 200}} <- RTSP.get_parameter(session) do
      Process.send_after(self(), :ping, 15_000)
      {:noreply, session}
    else
      error ->
        Logger.warn("RTSP ping failed: #{inspect(error)}")
        {:stop, session, :request_failed}
    end
  end
end
