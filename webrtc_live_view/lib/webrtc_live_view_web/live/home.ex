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
            Boombox.run(
              input: {:webrtc, ingress_signaling},
              output: {:stream, video: :image, audio: false}
            )
            |> Stream.map(fn %Boombox.Packet{payload: image} = packet ->
              alias Evision.{ColorConversionCodes, Constant}

              {:ok, image} = Image.to_evision(image)

              grayscale = Evision.cvtColor(image, ColorConversionCodes.cv_COLOR_BGR2GRAY())
              flags = Bitwise.bor(Constant.cv_THRESH_BINARY(), Constant.cv_THRESH_OTSU())
              {_ok, bw} = Evision.threshold(grayscale, 50, 255, flags)

              {contours, _} = Evision.findContours(
                bw, Constant.cv_RETR_LIST(), Constant.cv_CHAIN_APPROX_NONE()
              )

              contours =
                Enum.filter(contours, fn c ->
                  trunc(Evision.contourArea(c)) in 100..200_000
                end)

              {:ok, image} =
                Evision.drawContours(
                  image, contours, index = -1, edge_color = {0, 0, 255}, thickness: 2
                )
                |> Image.from_evision()

              %Boombox.Packet{packet | payload: image}
            end)
            |> Boombox.run(
              input: {:stream, video: :image, audio: false},
              output: {:webrtc, egress_signaling}
            )
          end)

        socket
        |> Capture.attach(
          id: "mediaCapture",
          signaling: ingress_signaling,
          audio?: false,
          video?: true
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
