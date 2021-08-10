defmodule Membrane.Demo.AudioPipeline do
  @moduledoc """
  Documentation for `VideoMixer`.
  """
  use Membrane.Pipeline
  alias Membrane.File.{Sink, Source}
  alias Membrane.WAV.Parser
  alias Membrane.AudioMixer

  @impl true
  def handle_init({path_to_wav_1, path_to_wav_2}) do
    children = %{
      # Stream from file
      audio_file_1: %Source{location: path_to_wav_1},
      audio_file_2: %Source{location: path_to_wav_2},
      # Parse each wav file to raw audio
      parser_1: Parser,
      parser_2: Parser,
      # Mix two files
      mixer: %AudioMixer{
        caps: %Membrane.Caps.Audio.Raw{
          channels: 1,
          sample_rate: 16_000,
          format: :s16le
        }
      },
      # Convert mixed audio to aac format
      aac_fdk: Membrane.AAC.FDK.Encoder,
      # Save output in a file
      file_sink: %Sink{location: "output.aac"}
    }

    # Setup the flow of the data
    links = [
      # parse first file
      link(:audio_file_1)
      |> to(:parser_1)
      |> to(:mixer),
      # parse second file
      link(:audio_file_2)
      |> to(:parser_2)
      # offset file by 2 seconds
      |> via_in(:input, options: [offset: Membrane.Time.milliseconds(2000)])
      |> to(:mixer),
      # save mixer's output in .aac format
      link(:mixer)
      |> to(:aac_fdk)
      |> to(:file_sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
