Logger.configure(level: :info)

Mix.install([
  {:membrane_core, "~> 1.0"},
  {:membrane_file_plugin, "~> 0.17.0"},
  {:membrane_wav_plugin, "~> 0.10.1"},
  {:membrane_audio_mix_plugin, "~> 0.16.0"},
  {:membrane_aac_fdk_plugin, "0.18.8"}
])

defmodule MixAudio do
  @moduledoc """
  Mix several .wav files into single .aac file.
  """
  use Membrane.Pipeline

  @impl true
  def handle_init(_ctx, {wav1, wav2}) do
    # Setup the flow of the data
    spec = [
      # Read & parse first WAV
      child(%Membrane.File.Source{location: wav1})
      |> child(Membrane.WAV.Parser)
      |> get_child(:mixer),
      # Read & parse second WAV
      child(%Membrane.File.Source{location: wav2})
      |> child(Membrane.WAV.Parser)
      # Offset audio by 2 seconds
      |> via_in(:input, options: [offset: Membrane.Time.seconds(2)])
      |> get_child(:mixer),
      # Spawn the mixer and setup the audio format that it should operate on
      child(:mixer, %Membrane.AudioMixer{
        stream_format: %Membrane.RawAudio{
          channels: 1,
          sample_rate: 16_000,
          sample_format: :s16le
        }
      })
      # Encode output to AAC
      |> child(Membrane.AAC.FDK.Encoder)
      # Save the output to file
      |> child(:sink, %Membrane.File.Sink{location: "output.aac"})
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_element_end_of_stream(:sink, :input, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end

{:ok, _supervisor, pipeline} =
  Membrane.Pipeline.start_link(MixAudio, {"sound_500f.wav", "sound_1000f.wav"})

Process.monitor(pipeline)

# Wait for the pipeline to terminate
receive do
  {:DOWN, _monitor, :process, ^pipeline, _reason} -> :ok
end
