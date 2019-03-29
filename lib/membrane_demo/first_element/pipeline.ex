defmodule Membrane.Demo.FirstElement.Pipeline do
  use Membrane.Pipeline

  @moduledoc """
  Pipeline that contains created element
  """

  @doc false
  def handle_init(path_to_mp3) do
    children = [
      file_src: %Membrane.Element.File.Source{location: path_to_mp3},
      decoder: Membrane.Element.Mad.Decoder,
      converter: %Membrane.Element.FFmpeg.SWResample.Converter{
        output_caps: %Membrane.Caps.Audio.Raw{
          format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      },
      # Here is a declaration of our element
      counter: %Membrane.Demo.FirstElement.Element{interval: 5000},
      sink: Membrane.Element.PortAudio.Sink
    ]

    links = %{
      {:file_src, :output} => {:decoder, :input},
      {:decoder, :output} => {:converter, :input},
      # link element between converter and sink
      {:converter, :output} => {:counter, :input, pad: [divisor: 10]},
      {:counter, :output} => {:sink, :input}
    }

    spec = %Membrane.Pipeline.Spec{
      children: children,
      links: links
    }

    {{:ok, spec}, %{}}
  end

  @impl true
  def handle_notification(notification, _elem_name, state) do
    IO.inspect(notification)
    {:ok, state}
  end
end
