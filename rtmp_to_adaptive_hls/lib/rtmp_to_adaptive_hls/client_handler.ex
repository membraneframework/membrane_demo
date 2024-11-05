defmodule Membrane.Demo.RtmpToAdaptiveHls.ClientHandler do
  @moduledoc """
  An implementation of `Membrane.RTMPServer.ClientHandlerBehaviour` compatible with the
  `Membrane.RTMP.Source` element, which also send information about RTMP stream metadata to the `pipeline` process
  """

  @behaviour Membrane.RTMPServer.ClientHandler

  @handler Membrane.RTMP.Source.ClientHandlerImpl

  defstruct []

  @impl true
  def handle_init(%{pipeline: pid} = opts) do
    state = @handler.handle_init(opts)
    Map.put(state, :pipeline, pid)
  end

  @impl true
  defdelegate handle_info(msg, state), to: @handler

  @impl true
  defdelegate handle_data_available(payload, state), to: @handler

  @impl true
  defdelegate handle_connection_closed(state), to: @handler

  @impl true
  defdelegate handle_delete_stream(state), to: @handler

  @impl true
  def handle_metadata(message, state) do
    send(state.pipeline, message)
    state
  end
end
