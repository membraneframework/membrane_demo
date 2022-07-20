defmodule HlsProxyApi.Application do
  @moduledoc false
  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: HlsProxyApi.Registry},
      HlsProxyApi.Connection.ConnectionSupervisor,
      HlsProxyApi.Connection.ConnectionStarter
    ]

    Logger.debug("Application is starting")

    Supervisor.start_link(children, strategy: :one_for_one, name: HlsProxyApi.Supervisor)
  end
end
