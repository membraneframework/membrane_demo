defmodule Membrane.Demo.RTP.SendPipeline do
  use Membrane.Pipeline

  alias Membrane.RTP

  @impl true
  def handle_init(opts) do
    %{
      secure?: secure?,
      audio_port: audio_port,
      video_port: video_port,
      audio_ssrc: audio_ssrc,
      video_ssrc: video_ssrc
    } = opts

    spec = %ParentSpec{
      children: [
        video_src: %Membrane.Hackney.Source{
          location: "https://membraneframework.github.io/static/samples/ffmpeg-testsrc.h264",
          hackney_opts: [follow_redirect: true]
        },
        video_parser: %Membrane.H264.FFmpeg.Parser{framerate: {30, 1}, alignment: :nal},
        audio_src: %Membrane.File.Source{
          location: "test/audio.raw"
        },
        audio_encoder: %Membrane.Opus.Encoder{
          input_caps: %Membrane.RawAudio{
            sample_format: :s16le,
            channels: 2,
            sample_rate: 48000
          }
        },
        audio_parser: Membrane.Opus.Parser,
        rtp: %RTP.SessionBin{
          secure?: secure?,
          srtp_policies: [
            %ExLibSRTP.Policy{
              ssrc: :any_inbound,
              key: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            }
          ]
        },
        video_realtimer: Membrane.Realtimer,
        video_sink: %Membrane.UDP.Sink{
          destination_port_no: video_port,
          destination_address: {127, 0, 0, 1}
        },
        audio_realtimer: Membrane.Realtimer,
        audio_sink: %Membrane.UDP.Sink{
          destination_port_no: audio_port,
          destination_address: {127, 0, 0, 1}
        }
      ],
      links: [
        link(:video_src)
        |> to(:video_parser)
        |> via_in(Pad.ref(:input, video_ssrc), options: [payloader: Membrane.RTP.H264.Payloader])
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, video_ssrc), options: [encoding: :H264])
        |> to(:video_realtimer)
        |> to(:video_sink),
        #
        link(:audio_src)
        |> to(:audio_encoder)
        |> to(:audio_parser)
        |> via_in(Pad.ref(:input, audio_ssrc), options: [payloader: Membrane.RTP.Opus.Payloader])
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, audio_ssrc), options: [encoding: :OPUS])
        |> to(:audio_realtimer)
        |> to(:audio_sink)
      ]
    }

    {{:ok, spec: spec, playback: :playing}, %{}}
  end
end
