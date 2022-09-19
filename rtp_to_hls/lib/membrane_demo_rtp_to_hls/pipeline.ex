defmodule Membrane.Demo.RtpToHls.Pipeline do
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(%{video_port: video_port, audio_port: audio_port}) do
    children = %{
      video_source: %Membrane.UDP.Source{
        local_port_no: video_port,
        recv_buffer_size: 500_000
      },
      audio_source: %Membrane.UDP.Source{
        local_port_no: audio_port,
        recv_buffer_size: 500_000
      },
      rtp: Membrane.RTP.SessionBin,
      hls: %Membrane.HTTPAdaptiveStream.Sink{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 10 |> Membrane.Time.seconds(),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }
    }

    links = [
      link(:video_source)
      |> via_in(Pad.ref(:rtp_input, :video))
      |> to(:rtp),
      link(:audio_source)
      |> via_in(Pad.ref(:rtp_input, :audio))
      |> to(:rtp)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec, playback: :playing}, %{}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 96, _ext}, :rtp, _ctx, state) do
    children = %{
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },
      video_payloader: Membrane.MP4.Payloader.H264,
      video_cmaf_muxer: Membrane.MP4.Muxer.CMAF
    }

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.H264.Depayloader])
      |> to(:video_nal_parser)
      |> to(:video_payloader)
      |> to(:video_cmaf_muxer)
      |> to(:hls)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:new_rtp_stream, ssrc, 127, _ext}, :rtp, _ctx, state) do
    children = %{
      # fills dropped frames with empty audio, needed for players that
      # don't care about audio timestamps, like Safari
      # audio_filler: Membrane.AAC.Filler,
      audio_payloader: Membrane.MP4.Payloader.AAC,
      audio_cmaf_muxer: Membrane.MP4.Muxer.CMAF
    }

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.AAC.Depayloader])
      # |> to(:audio_filler)
      |> to(:audio_payloader)
      |> to(:audio_cmaf_muxer)
      |> via_in(:input)
      |> to(:hls)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:new_rtp_stream, ssrc, _}, :rtp, _ctx, state) do
    Logger.warn("Unsupported stream connected")

    children = [
      {{:fake_sink, ssrc}, Membrane.Fake.Sink.Buffers}
    ]

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> to({:fake_sink, ssrc})
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification(_notification, _element, _ctx, state) do
    {:ok, state}
  end
end
