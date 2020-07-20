defmodule Membrane.Demo.RtpToHls.Pipeline do
  use Membrane.Pipeline
  alias Membrane.Time

  require Logger

  @impl true
  def handle_init(port) do
    children = %{
      app_source: %Membrane.Element.UDP.Source{
        local_port_no: port,
        recv_buffer_size: 100_0000
        # packets_per_buffer: 20
      },
      rtp: %Membrane.RTP.Session.ReceiveBin{
        fmt_mapping: %{96 => :H264, 127 => :AAC},
        custom_depayloaders: %{
          :H264 => Membrane.RTP.H264.Depayloader,
          :AAC => %Membrane.RTP.AAC.Depayloader{channels: 1}
        }
      },
      hls: %Membrane.HTTPAdaptiveStream.Sink{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 10 |> Membrane.Time.seconds(),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }
    }

    links = [
      link(:app_source) |> via_in(:input, buffer: [fail_size: 300]) |> to(:rtp)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, %{}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, :H264}, :rtp, state) do
    children = %{
      # TODO: remove when moved to the RTP bin
      video_timestamper: %Membrane.RTP.Timestamper{
        resolution: Ratio.new(Time.second(), 90_000)
      },
      video_nal_parser: %Membrane.Element.FFmpeg.H264.Parser{
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
      |> to(:video_timestamper)
      |> to(:video_nal_parser)
      |> to(:video_payloader)
      |> to(:video_cmaf_muxer)
      |> via_in(:input)
      |> to(:hls)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:new_rtp_stream, ssrc, :AAC}, :rtp, state) do
    children = %{
      # TODO: remove when moved to the RTP bin
      audio_timestamper: %Membrane.RTP.Timestamper{
        resolution: Ratio.new(Time.second(), 44100)
      },
      # fills dropped frames with empty audio, because Safari player doesn't
      # care about audio timestamps; assumes initial timestamp is equal to 0
      # audio_filler: Membrane.AAC.Filler,
      audio_payloader: Membrane.MP4.Payloader.AAC,
      audio_cmaf_muxer: Membrane.MP4.CMAF.Muxer
    }

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> to(:audio_timestamper)
      # |> to(:audio_filler)
      |> to(:audio_payloader)
      |> to(:audio_cmaf_muxer)
      |> via_in(:input)
      |> to(:hls)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:new_rtp_stream, ssrc, _}, :rtp, state) do
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

  def handle_notification(_notification, _element, state) do
    {:ok, state}
  end
end
