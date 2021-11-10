defmodule Membrane.Demo.VideoPipeline do
  @moduledoc """
  Merge several .h264 files into single .h264 file.
  """
  use Membrane.Pipeline
  alias Membrane.VideoCutAndMerge
  alias Membrane.H264.FFmpeg.{Parser, Decoder, Encoder}
  alias Membrane.File.{Sink, Source}

  @impl true
  def handle_init({path_to_file_1, path_to_file_2}) do
    children = %{
      # Stream from file
      file_1: %Source{chunk_size: 40_960, location: path_to_file_1},
      file_2: %Source{chunk_size: 40_960, location: path_to_file_2},
      # add timestamps
      parser_1: %Parser{framerate: {25, 1}},
      parser_2: %Parser{framerate: {25, 1}},
      # decode h264 file to raw video
      decoder_1: Decoder,
      decoder_2: Decoder,
      # cut and merge 2 videos into one
      cut_and_merge: VideoCutAndMerge,
      # encode output in h264 format
      encoder: Encoder,
      # save output to file
      sink: %Sink{location: "output.h264"}
    }

    # take first 5 seconds form the first file
    stream_1 = %VideoCutAndMerge.Stream{intervals: [{0, Membrane.Time.seconds(5)}]}
    # take everything but the first 5 seconds from the second file
    stream_2 = %VideoCutAndMerge.Stream{intervals: [{Membrane.Time.seconds(5), :infinity}]}

    # Setup the flow of the data
    links = [
      # parse and decode first file
      link(:file_1)
      |> to(:parser_1)
      |> to(:decoder_1)
      # pass it to :cut_and_merge with specified stream
      |> via_in(Pad.ref(:input, 1), options: [stream: stream_1])
      |> to(:cut_and_merge),
      # repeat for second file
      link(:file_2)
      |> to(:parser_2)
      |> to(:decoder_2)
      |> via_in(Pad.ref(:input, 2), options: [stream: stream_2])
      |> to(:cut_and_merge),
      # encode and save :cut_and_merge output to .h264 format
      link(:cut_and_merge)
      |> to(:encoder)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
