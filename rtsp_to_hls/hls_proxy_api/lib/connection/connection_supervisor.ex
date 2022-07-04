defmodule HlsProxyApi.Connection.ConnectionSupervisor do
  @moduledoc false
  use DynamicSupervisor

  require Logger

  alias HlsProxyApi.Connection.ConnectionManager
  alias HlsProxyApi.Streams.Stream

  @spec start_link(Keyword.t()) :: Supervisor.on_start()
  def start_link(_args) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @spec start_stream(__MODULE__, Stream.t()) :: Supervisor.on_start_child()
  def start_stream(supervisor, %Stream{id: id} = stream) do
    Logger.debug("ConnectionSupervisor: Starting stream #{id}")

    DynamicSupervisor.start_child(supervisor, %{
      id: "ConnectionManager_#{id}",
      start: {ConnectionManager, :start_link, [stream]},
      restart: :transient
    })
  end

  @impl true
  def init(_args) do
    Logger.debug("ConnectionSupervisor: Initializing")
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
