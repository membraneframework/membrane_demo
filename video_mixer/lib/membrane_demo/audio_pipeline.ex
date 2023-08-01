defmodule Membrane.Demo.AudioPipeline do
  @moduledoc """
  Mix several .wav files into single .aac file.
  """
  use Membrane.Pipeline
  alias Membrane.File.{Sink, Source}
  alias Membrane.WAV.Parser
  alias Membrane.AudioMixer

  @impl true
  def handle_init(_ctx, {path_to_wav_1, path_to_wav_2}) do
    # Setup the flow of the data
    spec = [
      # parse first file
      child(:audio_file_1, %Source{location: path_to_wav_1})
      |> child(:parser_1, Parser)
      |> child(:mixer, %AudioMixer{
        stream_format: %Membrane.RawAudio{
          channels: 1,
          sample_rate: 16_000,
          sample_format: :s16le
        }
      }),
      # parse second file
      child(:audio_file_2, %Source{location: path_to_wav_2})
      |> child(:parser_2, Parser)
      # offset file by 2 seconds
      |> via_in(:input, options: [offset: Membrane.Time.milliseconds(2000)])
      |> get_child(:mixer),
      # convert and save mixer's output in .aac format
      get_child(:mixer)
      |> child(:aac_fdk, Membrane.AAC.FDK.Encoder)
      |> child(:file_sink, %Sink{location: "output.aac"})
    ]

    {[spec: spec], %{}}
  end
end
