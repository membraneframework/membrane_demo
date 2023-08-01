defmodule Membrane.Demo.VideoPipeline do
  @moduledoc """
  Merge several .h264 files into single .h264 file.
  """
  use Membrane.Pipeline
  alias Membrane.VideoCutAndMerge
  alias Membrane.H264.FFmpeg.{Parser, Decoder, Encoder}
  alias Membrane.File.{Sink, Source}

  @impl true
  def handle_init(_ctx, {path_to_file_1, path_to_file_2}) do
    # take first 5 seconds form the first file
    stream_1 = %VideoCutAndMerge.Stream{intervals: [{0, Membrane.Time.seconds(5)}]}
    # take everything but the first 5 seconds from the second file
    stream_2 = %VideoCutAndMerge.Stream{intervals: [{Membrane.Time.seconds(5), :infinity}]}

    # Setup the flow of the data
    spec = [
      # parse and decode first file
      child(:file_1, %Source{chunk_size: 40_960, location: path_to_file_1})
      |> child(:parser_1, %Parser{framerate: {25, 1}})
      |> child(:decoder_1, Decoder)
      # pass it to :cut_and_merge with specified stream
      |> via_in(Pad.ref(:input, 1), options: [stream: stream_1])
      |> child(:cut_and_merge, VideoCutAndMerge),
      # repeat for second file
      child(:file_2, %Source{chunk_size: 40_960, location: path_to_file_2})
      |> child(:parser_2, %Parser{framerate: {25, 1}})
      |> child(:decoder_2, Decoder)
      |> via_in(Pad.ref(:input, 2), options: [stream: stream_2])
      |> get_child(:cut_and_merge),
      # encode and save :cut_and_merge output to .h264 format
      get_child(:cut_and_merge)
      # encode output in h264 format
      |> child(:encoder, Encoder)
      # save output to file
      |> child(:sink, %Sink{location: "output.h264"})
    ]

    {[spec: spec], %{}}
  end
end
