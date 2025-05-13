defmodule Membrane.Demo.RTP.ReceivePipeline do
  use Membrane.Pipeline

  require Logger

  alias Membrane.{H264, Opus, RTP, UDP}

  @local_ip {127, 0, 0, 1}

  @impl true
  def handle_init(_ctx, opts) do
    %{audio_port: audio_port, video_port: video_port, secure?: secure?, srtp_key: srtp_key} = opts

    srtp =
      if secure? do
        [%ExLibSRTP.Policy{ssrc: :any_inbound, key: srtp_key}]
      else
        false
      end

    spec =
      {[
         child(:video_src, %UDP.Source{
           local_port_no: video_port,
           local_address: @local_ip
         })
         |> child(:video_rtp_demuxer, %RTP.Demuxer{srtp: srtp})
         |> via_out(:output, options: [stream_id: {:encoding_name, :H264}])
         |> child(:video_depayloader, RTP.H264.Depayloader)
         |> child(:video_parser, %H264.Parser{
           generate_best_effort_timestamps: %{framerate: {30, 1}}
         })
         |> child(:video_decoder, H264.FFmpeg.Decoder)
         |> child(:video_player, Membrane.SDL.Player),
         child(:audio_src, %UDP.Source{
           local_port_no: audio_port,
           local_address: @local_ip
         })
         |> child(:audio_rtp_demuxer, %RTP.Demuxer{srtp: srtp})
         |> via_out(:output, options: [stream_id: {:encoding_name, :opus}])
         |> child(:audio_depayloader, RTP.Opus.Depayloader)
         |> child(:audio_decoder, Opus.Decoder)
         |> child(:audio_player, Membrane.PortAudio.Sink)
       ], stream_sync: :sinks}

    {[spec: spec], %{}}
  end
end
