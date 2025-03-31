defmodule Membrane.CountoursDrawer do
  use Membrane.Filter

  alias Evision.{ColorConversionCodes, Constant}

  def_input_pad :input, accepted_format: Membrane.RawVideo
  def_output_pad :output, accepted_format: Membrane.RawVideo

  @impl true
  def handle_buffer(:input, buffer, ctx, state) do
    %{height: height, width: width} = ctx.pads.input.stream_format

    {:ok, image} =
      Vix.Vips.Image.new_from_binary(buffer.payload, width, height, 3, :VIPS_FORMAT_UCHAR)

    {:ok, image} = Image.to_evision(image)

    grayscale = Evision.cvtColor(image, ColorConversionCodes.cv_COLOR_BGR2GRAY())
    flags = Bitwise.bor(Constant.cv_THRESH_BINARY(), Constant.cv_THRESH_OTSU())
    {_ok, bw} = Evision.threshold(grayscale, 50, 255, flags)

    {contours, _} =
      Evision.findContours(
        bw,
        Constant.cv_RETR_LIST(),
        Constant.cv_CHAIN_APPROX_NONE()
      )

    contours =
      Enum.filter(contours, fn c ->
        trunc(Evision.contourArea(c)) in 100..200_000
      end)

    {:ok, image} =
      image
      |> Evision.drawContours(contours, _index = -1, _edge_color = {0, 0, 255}, thickness: 2)
      |> Image.from_evision()

    payload =
      image |> Image.flatten!() |> Image.to_colorspace!(:srgb) |> Vix.Vips.Image.write_to_binary()

    buffer = %Membrane.Buffer{buffer | payload: payload}
    {[buffer: buffer], state}
  end
end

defmodule MyPipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, opts) do
    spec =
      child(:webrtc_source, %Membrane.WebRTC.Source{
        allowed_video_codecs: :h264,
        signaling: opts[:ingress_signaling]
      })
      |> via_out(:output, options: [kind: :video])
      |> child(%Membrane.Transcoder{output_stream_format: Membrane.RawVideo})
      |> child(%Membrane.FFmpeg.SWScale.Converter{format: :RGB})
      |> child(Membrane.CountoursDrawer)
      |> child(%Membrane.FFmpeg.SWScale.Converter{format: :I420})
      |> child(%Membrane.Transcoder{
        output_stream_format: %Membrane.H264{alignment: :nalu, stream_structure: :annexb}
      })
      |> via_in(:input, options: [kind: :video])
      |> child(:webrtc_sink, %Membrane.WebRTC.Sink{
        video_codec: :h264,
        signaling: opts[:egress_signaling]
      })

    {[spec: spec], %{}}
  end
end

defmodule WebrtcLiveViewWeb.Live.EchoLive do
  use WebrtcLiveViewWeb, :live_view

  alias Evision.{ColorConversionCodes, Constant}
  alias Membrane.WebRTC.Live.{Capture, Player}

  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        ingress_signaling = Membrane.WebRTC.Signaling.new()
        egress_signaling = Membrane.WebRTC.Signaling.new()

        {:ok, _task_pid} =
          Task.start_link(fn ->
            {:ok, supervisor, pipeline} =
              Membrane.Pipeline.start_link(MyPipeline,
                ingress_signaling: ingress_signaling,
                egress_signaling: egress_signaling
              )

            # Boombox.run(
            #   input: {:webrtc, ingress_signaling},
            #   output: {:stream, video: :image, audio: false}
            # )
            # |> Stream.map(fn %Boombox.Packet{payload: image} = packet ->
            #   image = draw_countours(image)
            #   %Boombox.Packet{packet | payload: image}
            # end)
            # |> Boombox.run(
            #   input: {:stream, video: :image, audio: false},
            #   output: {:webrtc, egress_signaling}
            # )
          end)

        socket
        |> Capture.attach(
          id: "mediaCapture",
          signaling: ingress_signaling,
          audio?: false,
          video?: true
          # preview?: false
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

  defp draw_countours(image) do
    {:ok, image} = Image.to_evision(image)

    grayscale = Evision.cvtColor(image, ColorConversionCodes.cv_COLOR_BGR2GRAY())
    flags = Bitwise.bor(Constant.cv_THRESH_BINARY(), Constant.cv_THRESH_OTSU())
    {_ok, bw} = Evision.threshold(grayscale, 50, 255, flags)

    {contours, _} =
      Evision.findContours(
        bw,
        Constant.cv_RETR_LIST(),
        Constant.cv_CHAIN_APPROX_NONE()
      )

    contours =
      Enum.filter(contours, fn c ->
        trunc(Evision.contourArea(c)) in 100..200_000
      end)

    {:ok, image} =
      image
      |> Evision.drawContours(contours, _index = -1, _edge_color = {0, 0, 255}, thickness: 2)
      |> Image.from_evision()

    image
  end
end
