defmodule VideoRoom.WS do
  @behaviour :cowboy_websocket

  # Client API
  def offer_msg(sdp) do
    msg =
      Poison.encode!(%{
        "event" => "offer",
        "data" => %{
          "type" => "offer",
          "sdp" => sdp
        }
      })

    {:text, msg}
  end

  def candidate_msg(cand, sdpMLineIndex, sdpMid) do
    msg =
      Poison.encode!(%{
        "event" => "candidate",
        "data" => %{
          "candidate" => cand,
          "sdpMLineIndex" => sdpMLineIndex,
          "sdpMid" => sdpMid
        }
      })

    {:text, msg}
  end

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
  def websocket_handle({:text, msg}, state) do
    msg = Poison.decode!(msg)
    websocket_handle({:json, msg}, state)
  end

  @impl true
  def websocket_handle({:json, msg}, state) do
    case msg["event"] do
      "start" ->
        send(VideoRoom.Stream.Pipeline, {:new_peer, self()})
        {:ok, state}

      "stop" ->
        Membrane.Pipeline.stop_and_terminate(VideoRoom.Stream.Pipeline)
        {:ok, state}

      _ ->
        send(VideoRoom.Stream.Pipeline, {:event, self(), msg})
        {:ok, state}
    end
  end

  @impl true
  def websocket_info({:text, _msg} = frame, state) do
    {:reply, frame, state}
  end

  @impl true
  def websocket_info(_info, state) do
    {:ok, state}
  end
end
