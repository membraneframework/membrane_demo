defmodule Membrane.Demo.RTP.ReceivePipeline do
  use Membrane.Pipeline

  alias Membrane.RTP

  @impl true
  def handle_init(%{secure?: secure?, port: port, fmt_mapping: fmt_mapping}) do
    spec = %ParentSpec{
      children: [
        udp: %Membrane.Element.UDP.Source{local_port_no: port, local_address: {127, 0, 0, 1}},
        rtp: %RTP.SessionBin{
          secure?: secure?,
          srtp_policies: [
            %LibSRTP.Policy{
              ssrc: :any_inbound,
              key: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            }
          ],
          fmt_mapping: fmt_mapping
        }
      ],
      links: [link(:udp) |> via_in(:rtp_input) |> to(:rtp)]
    }

    {{:ok, spec: spec}, %{}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, :H264}, :rtp, _ctx, state) do
    video_parser = {:video_parser, ssrc}
    decoder = {:decoder, ssrc}
    player = {:player, ssrc}

    spec = %ParentSpec{
      children: %{
        video_parser => %Membrane.Element.FFmpeg.H264.Parser{framerate: {30, 1}},
        decoder => Membrane.Element.FFmpeg.H264.Decoder,
        player => Membrane.Element.SDL.Player
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc))
        |> to(video_parser)
        |> to(decoder)
        |> to(player)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, _ssrc, pt_name}, :rtp, _ctx, _state) do
    raise "Unsupported payload type: #{inspect(pt_name)}"
  end

  @impl true
  def handle_notification(_, _, _ctx, state) do
    {:ok, state}
  end
end
