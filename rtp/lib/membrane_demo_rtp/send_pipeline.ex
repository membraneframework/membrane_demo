defmodule Membrane.Demo.RTP.SendPipeline do
  use Membrane.Pipeline

  alias Membrane.RTP

  @impl true
  def handle_init(%{secure?: secure?, port: port, ssrc: ssrc, fmt_mapping: fmt_mapping}) do
    spec = %ParentSpec{
      children: [
        hackney: %Membrane.Element.Hackney.Source{
          location: "https://membraneframework.github.io/static/video-samples/test-video.h264"
        },
        parser: %Membrane.Element.FFmpeg.H264.Parser{framerate: {30, 1}},
        rtp: %RTP.SessionBin{
          secure?: secure?,
          srtp_policies: [
            %LibSRTP.Policy{
              ssrc: :any_inbound,
              key: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            }
          ],
          fmt_mapping: fmt_mapping
        },
        udp: %Membrane.Element.UDP.Sink{
          destination_port_no: port,
          destination_address: {127, 0, 0, 1}
        }
      ],
      links: [
        link(:hackney)
        |> to(:parser)
        |> via_in(Pad.ref(:input, ssrc))
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, ssrc), options: [payload_type: 96])
        |> to(:udp)
      ]
    }

    {{:ok, spec: spec}, %{}}
  end
end
