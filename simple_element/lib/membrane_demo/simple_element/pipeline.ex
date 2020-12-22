defmodule Membrane.Demo.SimpleElement.Pipeline do
  @moduledoc """
  Pipeline that contains `Membrane.Demo.SimpleElement.Counter` element.
  """

  use Membrane.Pipeline
  alias Membrane.{File, FFmpeg, MP3.MAD, PortAudio, Time}

  @impl true
  def handle_init(path_to_mp3) do
    children = %{
      file: %File.Source{location: path_to_mp3},
      decoder: MAD.Decoder,
      converter: %FFmpeg.SWResample.Converter{
        output_caps: %Membrane.Caps.Audio.Raw{
          format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      },
      # Here is the declaration of our element
      counter: %Membrane.Demo.SimpleElement.Counter{interval: 5 |> Time.seconds()},
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
  def handle_notification(notification, _from, _ctx, state) do
    IO.inspect(notification)
    {:ok, state}
  end
end
