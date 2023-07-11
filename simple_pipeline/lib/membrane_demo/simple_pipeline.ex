defmodule Membrane.Demo.SimplePipeline do
  @moduledoc """
  Sample Membrane pipeline that will play an `.mp3` file.
  """

  use Membrane.Pipeline
  import Membrane.ChildrenSpec

  @doc """
  In order to play `.mp3` file we need to read it first.

  In membrane every entry point to data flow is called `Source`. Since we want
  to play a `file`, we will use `File.Source`.

  Next problem that arises is the fact that we are reading MPEG Layer 3 frames
  not raw audio. To deal with that we need to use `Filter` called decoder. It
  takes `.mp3` frames and yields RAW audio data.

  There is one tiny problem here though. Decoder returns `%Raw{format: :s24le}`
  data, but PortAudio (module that actually talks with the audio driver of your
  computer) wants `%Raw{format: :s16le, sample_rate: 48000, channels: 2}`.

  That's where `SWResample.Converter` comes into play. It will consume data that
  doesn't suite our needs and will yield data in format we want.
  """
  @impl true
  def handle_init(_context, path_to_mp3) do

    structure = [
      child(:file, %Membrane.File.Source{location: path_to_mp3}),
      child(:decoder, Membrane.MP3.MAD.Decoder),
      child(:converter, %Membrane.FFmpeg.SWResample.Converter{
        output_stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      }),
      child(:portaudio, Membrane.PortAudio.Sink),
      get_child(:file) |> get_child(:decoder) |> get_child(:converter) |> get_child(:portaudio)
    ]

    {[spec: structure, playback: :playing], %{}}
  end
end
