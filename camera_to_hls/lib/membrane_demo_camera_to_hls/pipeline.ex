defmodule Membrane.Demo.CameraToHls.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      # Captures video from the camera (raw video, depending on camera/os)
      source: Membrane.CameraCapture,
      # Converts pixel format to I420 (this is still a raw video)
      converter: %Membrane.FFmpeg.SWScale.PixelFormatConverter{format: :I420},
      # Takes raw video in I420 pixel format and encodes it into H264.
      # Baseline profile tells encoder not to generate
      # B-frames because browsers can't render them properly
      encoder: %Membrane.H264.FFmpeg.Encoder{profile: :baseline},
      # Creates caps, generates metadata and timestamps the stream based on it
      # Also, we generate the timestamps based on the framerate specified
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },

      # Below element is a combination of:
      #  - Membrane.MP4.Payloader.H264
      #  - Membrane.MP4.Muxer.CMAF
      #  - Membrane.HTTPAdaptiveStream.Sink

      # Generates caps for mp4
      # H264 is converted from Annex B form to length prefixed form.
      # Payloads the H264 so that it can be injected into MP4
      # Performs CMAF muxing
      # Generates segments (containers without header) of specified length
      # # Which than can be used in HLS to transport data in chunks
      # Generating playlists (according to HLS specification in this case) and persisting them in the storage location along side segments and headers
      hls_sink: %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }
    ]

    links = [
      link(:source)
      |> to(:converter)
      |> to(:encoder)
      |> to(:video_nal_parser)
      |> via_in(:input,
        options: [encoding: :H264, track_name: "My first track"]
      )
      |> to(:hls_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
