defmodule Membrane.Demo.RTP.SendPipeline do
  use Membrane.Pipeline

  alias Membrane.{File, H264, Opus, RTP, UDP}

  @impl true
  def handle_init(_ctx, opts) do
    %{
      audio_port: audio_port,
      video_port: video_port,
      audio_ssrc: audio_ssrc,
      video_ssrc: video_ssrc,
      secure?: secure?,
      srtp_key: srtp_key
    } = opts

    spec = [
      child(:video_src, %File.Source{
        location: "samples/video.h264"
      })
      |> child(:video_parser, %H264.Parser{
        generate_best_effort_timestamps: %{framerate: {30, 1}},
        output_alignment: :nalu
      })
      |> via_in(Pad.ref(:input, video_ssrc), options: [payloader: RTP.H264.Payloader])
      |> child(:rtp, %RTP.SessionBin{
        secure?: secure?,
        srtp_policies: [
          %ExLibSRTP.Policy{
            ssrc: :any_inbound,
            key: srtp_key
          }
        ]
      })
      |> via_out(Pad.ref(:rtp_output, video_ssrc), options: [encoding: :H264])
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
      |> via_in(Pad.ref(:input, audio_ssrc), options: [payloader: RTP.Opus.Payloader])
      |> get_child(:rtp)
      |> via_out(Pad.ref(:rtp_output, audio_ssrc), options: [encoding: :OPUS])
      |> child(:audio_realtimer, Membrane.Realtimer)
      |> child(:audio_sink, %UDP.Sink{
        destination_port_no: audio_port,
        destination_address: {127, 0, 0, 1}
      })
    ]

    {[spec: spec], %{}}
  end
end
