defmodule Membrane.Demo.CameraToHls.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      source: Membrane.CameraCapture,
      # Converts pixel_formats MV12? to I420 ??a bit losy??
      converter: %Membrane.FFmpeg.SWScale.PixelFormatConverter{format: :I420},
      # Takes raw I420 frames and converts to H264
      # No B-frames that browser can't handle them

      # There can be I-frames problem when encoder
      encoder: %Membrane.H264.FFmpeg.Encoder{profile: :baseline},
      # Creates caps, wyciaga metadane i dopisuje timestampy
      # Konczy sie  idea framerate bo dalej mamy timestampowane frame'y
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },
      # Generuje capsy do mp4, przeksztalca H264
      # Ten sam H264 lezy w mp4, rozniacy sie sposobem podzialu
      video_payloader: Membrane.MP4.Payloader.H264,
      # We don't have an audio, so we put video to container
      # and we mux everything to cmaf
      # CMAF wypluwa mini containerki
      # Czyli CMAF zajmuje sie dzieleniem
      video_cmaf_muxer: Membrane.MP4.Muxer.CMAF,
      #
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
