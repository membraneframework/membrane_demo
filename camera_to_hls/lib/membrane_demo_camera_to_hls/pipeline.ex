defmodule Membrane.Demo.CameraToHls.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      source: Membrane.CameraCapture,
      converter: %Membrane.FFmpeg.SWScale.PixelFormatConverter{format: :I420},
      encoder: Membrane.H264.FFmpeg.Encoder,
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },
      video_payloader: Membrane.MP4.Payloader.H264,
      video_cmaf_muxer: Membrane.MP4.Muxer.CMAF,
      hls: %Membrane.HTTPAdaptiveStream.Sink{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }
    ]

    links = [
      link(:source)
      |> to(:converter)
      |> to(:encoder)
      |> to(:video_nal_parser)
      |> to(:video_payloader)
      |> to(:video_cmaf_muxer)
      |> to(:hls)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
