defmodule Membrane.Demo.RTP.SendPipeline do
  use Membrane.Pipeline

  alias Membrane.{File, H264, Opus, RTP, UDP}

  @impl true
  def handle_init(_ctx, opts) do
    %{
      audio_port: audio_port,
      video_port: video_port,
      secure?: secure?,
      srtp_key: srtp_key
    } = opts

    use_srtp =
      if secure? do
        {true, [%ExLibSRTP.Policy{ssrc: :any_inbound, key: srtp_key}]}
      else
        false
      end

    spec = [
      child(:video_src, %File.Source{
        location: "samples/video.h264"
      })
      |> child(:video_parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}},
        output_alignment: :nalu
      })
      |> child(:video_payloader, RTP.H264.Payloader)
      |> child(:video_rtp_muxer, %RTP.Muxer{use_srtp: use_srtp})
      |> child(:video_realtimer, Membrane.Realtimer)
      |> child(:video_sink, %UDP.Sink{
        destination_port_no: video_port,
        destination_address: {127, 0, 0, 1}
      }),
      child(:audio_src, %File.Source{
        location: "samples/audio.opus"
      })
      |> child(:audio_parser, %Opus.Parser{
        input_delimitted?: true,
        delimitation: :undelimit,
        generate_best_effort_timestamps?: true
      })
      |> child(:audio_payloader, RTP.Opus.Payloader)
      |> child(:audio_rtp_muxer, %RTP.Muxer{use_srtp: use_srtp})
      |> child(:audio_realtimer, Membrane.Realtimer)
      |> child(:audio_sink, %UDP.Sink{
        destination_port_no: audio_port,
        destination_address: {127, 0, 0, 1}
      })
    ]

    {[spec: spec], %{}}
  end
end
