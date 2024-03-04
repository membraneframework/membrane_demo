defmodule Videoroom.FlvPipeline do
  @moduledoc false

  use Membrane.Pipeline
  require Logger

  @impl true
  def handle_init(_ctx, [tracks, output_file]) do
    Logger.warning("handle_init")
    Logger.warning(tracks)
    Logger.warning(output_file)
    # spec =
    #   child(:file, %File.Source{location: path_to_mp3})
    #   |> child(:decoder, MAD.Decoder)
    #   |> child(:converter, %FFmpeg.SWResample.Converter{
    #     output_stream_format: %Membrane.RawAudio{
    #       sample_format: :s16le,
    #       sample_rate: 48000,
    #       channels: 2
    #     }
    #   })
    #   |> via_in(:input, options: [divisor: 10])
    #   |> child(:counter, %Membrane.Demo.SimpleElement.Counter{interval: Time.seconds(5)})
    #   |> child(:sink, PortAudio.Sink)
    spec = [
      # Part of pipeline which saves to FLV file
      # child(:muxer, Membrane.MP4.Muxer.ISOM)
      # child(:muxer, Membrane.FLV.Muxer)
      # child(:muxer, Membrane.Matroska.Muxer)
      child(:muxer, Membrane.MP4.Muxer.ISOM)
      |> child(:sink, %Membrane.File.Sink{location: output_file}),
      # Part of pipeline which reads from file and prepare video for muxing
      child(:source, %Membrane.File.Source{location: tracks.video})
      |> child(:deserializer_video, Membrane.Stream.Deserializer)
      |> child(:rtp_video, %Membrane.RTP.DepayloaderBin{
        depayloader: Membrane.RTP.H264.Depayloader,
        clock_rate: 90_000
      })
      |> child(:parser_video, %Membrane.H264.Parser{
        # generate_best_effort_timestamps: %{framerate: {0, 1}},
        output_stream_structure: :avc1
      })
      # |> via_in(Pad.ref(:video, 0))
      |> get_child(:muxer),
      # Part of pipeline which reads from file and prepare audio for muxing
      child(:source_audio, %Membrane.File.Source{location: tracks.audio})
      |> child(:deserializer_audio, Membrane.Stream.Deserializer)
      |> child(:rtp_audio, %Membrane.RTP.DepayloaderBin{
        depayloader: Membrane.RTP.Opus.Depayloader,
        clock_rate: 48_000
      })
      # |> child(:opus_parser, Membrane.Opus.Parser)
      |> child(:opus_decoder, Membrane.Opus.Decoder)
      |> child(:aac_encoder, Membrane.AAC.FDK.Encoder)
      |> child(:aac_parser, %Membrane.AAC.Parser{
        out_encapsulation: :none,
        output_config: :esds
      })
      # |> via_in(Pad.ref(:audio, 0))
      |> get_child(:muxer)
    ]

    {[spec: spec], %{}}
  end

  # the rest of the Example module is only used for termination of the pipeline after processing finishes
  @impl true
  def handle_element_end_of_stream(:sink, _pad, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_child, _pad, _ctx, state) do
    {[], state}
  end
end
