defmodule Membrane.Demo.Basic.FirstElement.Pipeline do
  @moduledoc """
  Pipeline that contains created element
  """

  use Membrane.Pipeline
  alias Membrane.Element.{File, Mad, FFmpeg, PortAudio}

  @impl true
  def handle_init(path_to_mp3) do
    children = %{
      file: %File.Source{location: path_to_mp3},
      decoder: Mad.Decoder,
      converter: %FFmpeg.SWResample.Converter{
        output_caps: %Membrane.Caps.Audio.Raw{
          format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      },
      # Here is a declaration of our element
      counter: %Membrane.Demo.Basic.FirstElement.Element{interval: 5000},
      sink: PortAudio.Sink
    }

    links = [
      link(:file)
      |> to(:decoder)
      |> to(:converter)
      |> via_in(:input, options: [divisor: 10])
      |> to(:counter)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end

  @impl true
  def handle_notification(notification, _elem_name, state) do
    IO.inspect(notification)
    {:ok, state}
  end
end
