defmodule WebRTCLiveView.CountoursDrawer do
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

    {:ok, payload} =
      image |> Image.flatten!() |> Image.to_colorspace!(:srgb) |> Vix.Vips.Image.write_to_binary()

    buffer = %Membrane.Buffer{buffer | payload: payload}
    {[buffer: {:output, buffer}], state}
  end
end
