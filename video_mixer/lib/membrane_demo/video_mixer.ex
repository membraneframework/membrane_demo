defmodule Membrane.Demo.VideoMixer do
  @moduledoc """
  Documentation for `VideoMixer`.
  """
  use Membrane.Pipeline

  @impl true
  def handle_init({path_to_wav_1, path_to_wav_2}) do
    children = %{
      # Stream from file
      file_1: %Membrane.File.Source{location: path_to_wav_1},
      file_2: %Membrane.File.Source{location: path_to_wav_2},
      parser_1: Membrane.WAV.Parser,
      parser_2: Membrane.WAV.Parser,
      mixer: %Membrane.AudioMixer{
        caps: %Membrane.Caps.Audio.Raw{
          channels: 1,
          sample_rate: 16_000,
          format: :s16le
        }
      },
      converter: %Membrane.FFmpeg.SWResample.Converter{
        input_caps: %Membrane.Caps.Audio.Raw{channels: 1, sample_rate: 16_000, format: :s16le},
        output_caps: %Membrane.Caps.Audio.Raw{
          channels: 2,
          sample_rate: 48000,
          format: :s16le
        }
      },
      # Stream data into PortAudio to play it on speakers.
      portaudio: Membrane.PortAudio.Sink
    }

    # Setup the flow of the data
    links = [
      link(:file_1)
      |> to(:parser_1)
      |> to(:mixer)
      |> to(:converter)
      |> to(:portaudio),
      link(:file_2)
      |> to(:parser_2)
      |> via_in(:input, options: [offset: Membrane.Time.milliseconds(2000)])
      |> to(:mixer)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
