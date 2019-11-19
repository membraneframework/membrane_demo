defmodule Membrane.Demo.RTP.RTPPipeline do
  use Membrane.Pipeline

  alias Membrane.Bin.RTP

  @impl true
  def handle_init(%{fmt_mapping: fmt_mapping, port: port}) do
    spec = %ParentSpec{
      children: [
        udp: %Membrane.Element.UDP.Source{local_port_no: port, local_address: {127, 0, 0, 1}},
        rtp: %RTP.Receiver{fmt_mapping: fmt_mapping}
      ],
      links: [link(:udp) |> to(:rtp)]
    }

    {{:ok, spec: spec}, %{mpa: nil, h264: nil}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, "MPA"}, :rtp, state) do
    audio_player = {:audio_player, make_ref()}

    spec = %ParentSpec{
      children: %{
        audio_player => Membrane.Element.PortAudio.Sink
      },
      links: [
        link(:rtp) |> via_out(Pad.ref(:output, ssrc)) |> to(audio_player)
      ]
    }

    removal_action = if is_nil(state.mpa), do: [], else: [remove_child: state.mpa]

    {{:ok, removal_action ++ [spec: spec]}, %{state | mpa: audio_player}}
  end

  def handle_notification({:new_rtp_stream, ssrc, "H264"}, :rtp, state) do
    video_parser = {:video_parser, make_ref()}
    decoder = {:decoder, make_ref()}
    player = {:player, make_ref()}

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

    removal_action = if is_nil(state.h264), do: [], else: [remove_child: state.h264]

    {{:ok, removal_action ++ [spec: spec]}, state}
  end

  def handle_notification(_, _, state) do
    {:ok, state}
  end
end
