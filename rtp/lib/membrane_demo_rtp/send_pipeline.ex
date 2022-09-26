defmodule Membrane.Demo.RTP.SendPipeline do
  use Membrane.Pipeline

  alias Membrane.{File, H264, Opus, RTP, UDP}

  @impl true
  def handle_init(opts) do
    %{
      audio_port: audio_port,
      video_port: video_port,
      audio_ssrc: audio_ssrc,
      video_ssrc: video_ssrc,
      secure?: secure?,
      srtp_key: srtp_key
    } = opts

    spec = %ParentSpec{
      children: [
        video_src: %File.Source{
          location: "samples/video.h264"
        },
        video_parser: %H264.FFmpeg.Parser{framerate: {30, 1}, alignment: :nal},
        audio_src: %File.Source{
          location: "samples/audio.opus"
        },
        audio_parser: %Opus.Parser{
          input_delimitted?: true,
          delimitation: :undelimit
        },
        rtp: %RTP.SessionBin{
          secure?: secure?,
          srtp_policies: [
            %ExLibSRTP.Policy{
              ssrc: :any_inbound,
              key: srtp_key
            }
          ]
        },
        video_realtimer: Membrane.Realtimer,
        video_sink: %UDP.Sink{
          destination_port_no: video_port,
          destination_address: {127, 0, 0, 1}
        },
        audio_realtimer: Membrane.Realtimer,
        audio_sink: %UDP.Sink{
          destination_port_no: audio_port,
          destination_address: {127, 0, 0, 1}
        }
      ],
      links: [
        link(:video_src)
        |> to(:video_parser)
        |> via_in(Pad.ref(:input, video_ssrc), options: [payloader: RTP.H264.Payloader])
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, video_ssrc), options: [encoding: :H264])
        |> to(:video_realtimer)
        |> to(:video_sink),
        #
        link(:audio_src)
        |> to(:audio_parser)
        |> via_in(Pad.ref(:input, audio_ssrc), options: [payloader: RTP.Opus.Payloader])
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, audio_ssrc), options: [encoding: :OPUS])
        |> to(:audio_realtimer)
        |> to(:audio_sink)
      ]
    }

    {{:ok, spec: spec, playback: :playing}, %{}}
  end
end
