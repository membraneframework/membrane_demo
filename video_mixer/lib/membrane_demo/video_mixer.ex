defmodule Membrane.Demo.VideoMixer do
  @moduledoc """
  Documentation for `VideoMixer`.
  """
  use Membrane.Pipeline

  @impl true
  def handle_init({path_audio_1, path_audio_2, path_video_1, path_video_2}) do
    children = %{
      # Stream from file
      audio_file_1: %Membrane.File.Source{location: path_audio_1},
      audio_file_2: %Membrane.File.Source{location: path_audio_2},
      wav_parser_1: Membrane.WAV.Parser,
      wav_parser_2: Membrane.WAV.Parser,
      mixer: %Membrane.AudioMixer{
        caps: %Membrane.Caps.Audio.Raw{
          channels: 1,
          sample_rate: 16_000,
          format: :s16le
        }
      },
      aac_encoder: Membrane.AAC.FDK.Encoder,
      aac_payloader: Membrane.MP4.Payloader.AAC,
      video_file_1: %Membrane.File.Source{location: path_video_1},
      video_file_2: %Membrane.File.Source{location: path_video_2},
      h264_parser_1: %Membrane.H264.FFmpeg.Parser{framerate: {25, 1}},
      h264_parser_2: %Membrane.H264.FFmpeg.Parser{framerate: {25, 1}},
      h264_decoder_1: Membrane.H264.FFmpeg.Decoder,
      h264_decoder_2: Membrane.H264.FFmpeg.Decoder,
      cut_and_merge: Membrane.VideoCutAndMerge,
      h264_encoder: Membrane.H264.FFmpeg.Encoder,
      h264_payloader: Membrane.MP4.Payloader.H264,
      file_sink: %Membrane.File.Sink{location: "output.mp4"}
    }

    stream_1 = %Membrane.VideoCutAndMerge.Stream{intervals: [{0, Membrane.Time.seconds(5)}]}

    stream_2 = %Membrane.VideoCutAndMerge.Stream{
      intervals: [{Membrane.Time.seconds(5), :infinity}]
    }

    # Setup the flow of the data
    links = [
      link(:audio_file_1)
      |> to(:wav_parser_1)
      |> to(:mixer),
      link(:audio_file_2)
      |> to(:wav_parser_2)
      |> via_in(:input, options: [offset: Membrane.Time.milliseconds(2000)])
      |> to(:mixer),
      link(:mixer)
      |> to(:aac_encoder),
      link(:video_file_1)
      |> to(:h264_parser_1)
      |> to(:h264_decoder_1)
      |> via_in(Pad.ref(:input, 1), options: [stream: stream_1])
      |> to(:cut_and_merge),
      link(:video_file_2)
      |> to(:h264_parser_2)
      |> to(:h264_decoder_2)
      |> via_in(Pad.ref(:input, 2), options: [stream: stream_2])
      |> to(:cut_and_merge),
      link(:cut_and_merge)
      |> to(:h264_encoder)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
