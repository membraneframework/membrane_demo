defmodule VideoRoom.WS do
  @behaviour :cowboy_websocket

  alias VideoRoom.Stream.Pipeline

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
        "start" -> {:new_peer, self()}
        "answer" -> {:signal, self(), {:sdp_answer, msg["data"]["sdp"]}}
        "candidate" -> {:signal, self(), {:candidate, msg["data"]["candidate"]}}
        "stop" -> {:remove_peer, self()}
        _event -> nil
      end

    if msg, do: send(Pipeline, msg)
    {:ok, state}
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
  def websocket_info(_info, state) do
    {:ok, state}
  end
end
