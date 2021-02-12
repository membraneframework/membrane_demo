defmodule VideoRoom.WS do
  @behaviour :cowboy_websocket

  alias VideoRoom.Stream.Pipeline

  def signal(pid, {:sdp_offer, sdp}) do
    do_signal(pid, :offer, %{type: :offer, sdp: sdp})
  end

  def signal(pid, {:candidate, candidate, sdp_mline_index, _sdp_mid}) do
    do_signal(pid, :candidate, %{
      "candidate" => candidate,
      "sdpMLineIndex" => sdp_mline_index
    })
  end

  defp do_signal(pid, event, data) do
    send(pid, {:text, Poison.encode!(%{event: event, data: data})})
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
    msg =
      case msg["event"] do
        "start" -> {:new_peer, self()}
        "answer" -> {:signal, self(), {:sdp_answer, msg["data"]["sdp"]}}
        "candidate" -> {:signal, self(), {:candidate, msg["data"]["candidate"]}}
        _event -> nil
      end

    if msg, do: send(Pipeline, msg)
    {:ok, state}
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
