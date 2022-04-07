defmodule Membrane.Demo.CameraToHls.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      # Captures video from the camera (raw video, depending on camera/os)
      source: Membrane.CameraCapture,
      # Converts pixel format to I420 (this is still a raw video, but different format)
      converter: %Membrane.FFmpeg.SWScale.PixelFormatConverter{format: :I420},
      # Takes raw I420 frames and converts to H264
      # baseline profile tells encoder not to generate
      # B-frames because browsers can't handle them
      encoder: %Membrane.H264.FFmpeg.Encoder{profile: :baseline},
      # Creates caps, generates metadata and adds timestamps
      # There we need to specify framerate, based on it we
      # generate timestamps
      # Further we won't be able to control framerate
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },
      # Generates caps for mp4 by changing H264
      # It is the same H264, only difference is the way of division
      video_payloader: Membrane.MP4.Payloader.H264,
      # There we perform CMAF muxing
      # Simply put it generates containers of specified length
      # Which than can be used in HLS or other transporting protocols
      # to transport data in chunks
      video_cmaf_muxer: Membrane.MP4.Muxer.CMAF,
      # HLS element is responsible for generating HTTP streaming manifests.
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
