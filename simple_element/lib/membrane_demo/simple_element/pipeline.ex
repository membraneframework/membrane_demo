defmodule Membrane.Demo.SimpleElement.Pipeline do
  @moduledoc """
  Pipeline that contains `Membrane.Demo.SimpleElement.Counter` element.
  """

  use Membrane.Pipeline

  alias Membrane.{File, FFmpeg, MP3.MAD, PortAudio, Time}

  @impl true
  def handle_init(_ctx, path_to_mp3) do
    spec =
      child(:file, %File.Source{location: path_to_mp3})
      |> child(:decoder, MAD.Decoder)
      |> child(:converter, %FFmpeg.SWResample.Converter{
        output_stream_format: %Membrane.RawAudio{
          sample_format: :s16le,
          sample_rate: 48000,
          channels: 2
        }
      })
      |> via_in(:input, options: [divisor: 10])
      |> child(:counter, %Membrane.Demo.SimpleElement.Counter{interval: Time.seconds(5)})
      |> child(:sink, PortAudio.Sink)

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:counter, counter_value}, _from, _ctx, state) do
    IO.inspect(counter_value, label: "Count of buffers processed:")
    {[], state}
  end

  @impl true
  def handle_child_notification(notification, _from, _ctx, state) do
    {[], state}
  end
end
