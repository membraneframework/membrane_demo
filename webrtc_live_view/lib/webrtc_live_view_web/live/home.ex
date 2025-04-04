defmodule WebrtcLiveViewWeb.Live.EchoLive do
  use WebrtcLiveViewWeb, :live_view

  alias Membrane.WebRTC.Live.{Capture, Player}

  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        ingress_signaling = Membrane.WebRTC.Signaling.new()
        egress_signaling = Membrane.WebRTC.Signaling.new()

        {:ok, _task_pid} =
          Task.start_link(fn ->
            Membrane.Pipeline.start_link(WebRTCLiveView.Pipeline,
              ingress_signaling: ingress_signaling,
              egress_signaling: egress_signaling
            )
          end)

        socket
        |> Capture.attach(
          id: "mediaCapture",
          signaling: ingress_signaling,
          video?: true,
          audio?: false
        )
        |> Player.attach(
          id: "videoPlayer",
          signaling: egress_signaling
        )
      else
        socket
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <h3>Captured stream preview</h3>
    <Capture.live_render socket={@socket} capture_id="mediaCapture" />

    <h3>Stream sent by the server</h3>
    <Player.live_render socket={@socket} player_id="videoPlayer" />
    """
  end
end
