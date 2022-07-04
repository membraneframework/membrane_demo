defmodule HlsProxyApi.Connection.PortAgent do
  @moduledoc false
  use Agent

  @spec start_link(Keyword.t()) :: Agent.on_start()
  def start_link(_args) do
    Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)
  end

  @spec set_port(non_neg_integer()) :: :ok | {:error, :already_taken}
  def set_port(port) do
    Agent.get_and_update(
      __MODULE__,
      fn set ->
        if port in set do
          {{:error, :already_taken}, set}
        else
          {:ok, MapSet.put(set, port)}
        end
      end
    )
  end

  @spec remove(non_neg_integer()) :: :ok
  def remove(port) do
    Agent.update(__MODULE__, fn set -> MapSet.delete(set, port) end)
  end
end
