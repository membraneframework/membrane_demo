defmodule EchoDemo.Echo.WS do
  @behaviour :cowboy_websocket

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
    IO.inspect(msg)
    websocket_handle({:json, msg}, state)
  end

  def websocket_handle({:json, msg}, state) do
    case msg["event"] do
      "echo" ->
        {:ok, pid} = EchoDemo.Echo.Pipeline.start_link(ws_pid: self())
        EchoDemo.Echo.Pipeline.play(pid)
        {:ok, Map.put(state, :pipeline, pid)}
      _ ->
        send(state[:pipeline], {:event, msg})
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

  def handle_frame({_type, msg}, state) do
    send(state[:parent], {:event, msg})
    {:ok, state}
  end

  def send_offer(pid, sdp) do
    msg =
      Poison.encode!(%{
        "event" => "offer",
        "data" => %{
          "type" => "offer",
          "sdp" => sdp
        }
      })

    frame = {:text, msg}
    send(pid, frame)
  end

  def send_candidate(pid, cand, sdpMLineIndex, sdpMid) do
    msg =
      Poison.encode!(%{
        "event" => "candidate",
        "data" => %{
          "candidate" => cand,
          "sdpMLineIndex" => sdpMLineIndex,
          "sdpMid" => sdpMid
        }
      })

    frame = {:text, msg}
    send(pid, frame)
  end
end
