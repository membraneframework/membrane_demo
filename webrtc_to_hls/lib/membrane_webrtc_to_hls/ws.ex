defmodule Membrane.Demo.WebRTCToHLS.WS do
  @behaviour :cowboy_websocket

  alias Membrane.Demo.WebRTCToHLS.Pipeline

  require Logger

  # Server API
  @impl true
  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  @impl true
  def websocket_init(_state) do
    {:ok, %{}}
  end

  @impl true
  def websocket_handle({:text, "keep_alive"}, state) do
    {:ok, state}
  end

  @impl true
  def websocket_handle({:text, msg}, state) do
    msg = Poison.decode!(msg)

    msg =
      case msg["event"] do
        "start" -> :start
        "answer" -> {:signal, {:sdp_answer, msg["data"]["sdp"]}}
        "candidate" -> {:signal, {:candidate, msg["data"]["candidate"]}}
        "stop" -> :stop
        _event -> nil
      end

    case Pipeline.lookup(self()) do
      nil ->
        with {:ok, pipeline} = Pipeline.start(self()) do
          Process.monitor(pipeline)
          {:ok, pipeline}
        end

      pid ->
        {:ok, pid}
    end
    |> case do
      {:ok, pipeline} ->
        send(pipeline, msg)
        {:ok, state}

      {:error, reason} ->
        Logger.error("#{inspect(__MODULE__)} Failed to start pipeline: #{inspect(reason)}")
        {:stop, state}
    end
  end

  @impl true
  def websocket_info({:signal, msg}, state) do
    msg =
      case msg do
        {:candidate, candidate, sdp_mline_index} ->
          %{
            event: :candidate,
            data: %{
              "candidate" => candidate,
              "sdpMLineIndex" => sdp_mline_index
            }
          }

        {:sdp_offer, sdp} ->
          %{event: :offer, data: %{type: :offer, sdp: sdp}}
      end
      |> Poison.encode!()

    {:reply, {:text, msg}, state}
  end

  @impl true
  def websocket_info({:DOWN, _ref, :process, _pipeline, reason}, state) do
    Logger.error(
      "[#{inspect(__MODULE__)}] Pipeline is down with reason: #{inspect(reason)}, closing websocket #{
        inspect(self())
      }"
    )

    {:stop, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end
end
