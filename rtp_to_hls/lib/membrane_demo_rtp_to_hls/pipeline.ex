defmodule Membrane.Demo.RtpToHls.Pipeline do
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(port) do
    children = %{
      app_source: %Membrane.Element.UDP.Source{
        local_port_no: port,
        recv_buffer_size: 500_000
      },
      rtp: %Membrane.RTP.SessionBin{
        fmt_mapping: %{96 => {:H264, 90_000}, 127 => {:AAC, 48_000}},
        custom_depayloaders: %{
          :H264 => Membrane.RTP.H264.Depayloader,
          :AAC => Membrane.RTP.AAC.Depayloader
        }
      },
      hls: %Membrane.HTTPAdaptiveStream.Sink{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 10 |> Membrane.Time.seconds(),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }
    }

    links = [
      link(:app_source)
      |> via_in(Pad.ref(:rtp_input, make_ref()), buffer: [fail_size: 300])
      |> to(:rtp)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, %{}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 96}, :rtp, _ctx, state) do
    children = %{
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },
      video_payloader: Membrane.MP4.Payloader.H264,
      video_cmaf_muxer: Membrane.MP4.CMAF.Muxer
    }

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> to(:video_nal_parser)
      |> to(:video_payloader)
      |> to(:video_cmaf_muxer)
      |> via_in(:input)
      |> to(:hls)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:new_rtp_stream, ssrc, 127}, :rtp, _ctx, state) do
    children = %{
      # fills dropped frames with empty audio, needed for players that
      # don't care about audio timestamps, like Safari
      # audio_filler: Membrane.AAC.Filler,
      audio_payloader: Membrane.MP4.Payloader.AAC,
      audio_cmaf_muxer: Membrane.MP4.CMAF.Muxer
    }

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
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
      {{:fake_sink, ssrc}, Membrane.Element.Fake.Sink.Buffers}
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
