defmodule Membrane.Demo.RtspToHls.Pipeline do
  @moduledoc """
  The pipeline, which converts the RTP stream to HLS.
  """
  use Membrane.Pipeline

  require Logger

  alias Membrane.Demo.RtspToHls.ConnectionManager

  @impl true
  def handle_init(_ctx, options) do
    Logger.debug("Source handle_init options: #{inspect(options)}")

    connection_manager_spec = [
      %{
        id: "ConnectionManager",
        start:
          {ConnectionManager, :start_link,
           [
             [
               stream_url: options.stream_url,
               port: options.port,
               pipeline: self()
             ]
           ]},
        restart: :transient
      }
    ]

    Supervisor.start_link(connection_manager_spec,
      strategy: :one_for_one,
      name: Membrane.Demo.RtspToHls.Supervisor
    )

    {[playback: :playing], %{video: nil, port: options.port, output_path: options.output_path}}
  end

  @impl true
  def handle_info({:rtsp_setup_complete, options}, _ctx, state) do
    Logger.debug("Source received pipeline options: #{inspect(options)}")

    structure = [
      child(:app_source, %Membrane.UDP.Source{
        local_port_no: state[:port],
        recv_buffer_size: 500_000
      }),
      child(:rtp, %Membrane.RTP.SessionBin{
        fmt_mapping: %{96 => {:H264, 90_000}}
      }),
      child(:hls, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 120 |> Membrane.Time.seconds(),
#        target_segment_duration: 4 |> Membrane.Time.seconds(),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
          directory: state[:output_path]
        }
      }),
      get_child(:app_source)
      |> via_in(Pad.ref(:rtp_input, make_ref()))
      |> get_child(:rtp)
    ]

#    children = %{
#      app_source: %Membrane.UDP.Source{
#        local_port_no: state[:port],
#        recv_buffer_size: 500_000
#      },
#      rtp: %Membrane.RTP.SessionBin{
#        fmt_mapping: %{96 => {:H264, 90_000}}
#      },
#      hls: %Membrane.HTTPAdaptiveStream.SinkBin{
#        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
#        target_window_duration: 120 |> Membrane.Time.seconds(),
##        target_segment_duration: 4 |> Membrane.Time.seconds(),
#        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
#          directory: state[:output_path]
#        }
#      }
#    }

#    links = [
#      link(:app_source)
#      |> via_in(Pad.ref(:rtp_input, make_ref()))
#      |> to(:rtp)
#    ]

#    spec = %ParentSpec{children: children, links: links}
    {[spec: structure], %{state | video: %{sps: options[:sps], pps: options[:pps]}}}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, 96, _extensions} = msg, :rtp, _ctx, state) do
    Logger.info("#{inspect msg}")

    structure = [
      child(:video_nal_parser, %Membrane.H264.FFmpeg.Parser{
        sps: state.video.sps,
        pps: state.video.pps,
        skip_until_keyframe?: true,
        skip_until_parameters?: false,
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true,
      }),
      child(:video_payloader, Membrane.MP4.Payloader.H264),
      child(:video_cmaf_muxer, Membrane.MP4.Muxer.CMAF),
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc),
        options: [depayloader: Membrane.RTP.H264.Depayloader]
      )
      |> get_child(:video_nal_parser)
      |> get_child(:video_payloader)
      |> get_child(:video_cmaf_muxer)
      |> via_in(:input, options: [
        encoding: :H264,
        segment_duration: %Membrane.HTTPAdaptiveStream.Sink.SegmentDuration{min: 4, target: 5}
      ])
      |> get_child(:hls)
    ]

#    children = %{
#      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
#        sps: state.video.sps,
#        pps: state.video.pps,
#        skip_until_keyframe?: true,
#        skip_until_parameters?: false,
#        framerate: {30, 1},
#        alignment: :au,
#        attach_nalus?: true
#      },
#      video_payloader: Membrane.MP4.Payloader.H264,
#      video_cmaf_muxer: Membrane.MP4.Muxer.CMAF
#    }

#    links = [
#      link(:rtp)
#      |> via_out(Pad.ref(:output, ssrc),
#        options: [depayloader: Membrane.RTP.H264.Depayloader]
#      )
#      |> to(:video_nal_parser)
#      |> to(:video_payloader)
#      |> to(:video_cmaf_muxer)
#      |> via_in(:input)
#      |> to(:hls)
#    ]

    spec = structure

    actions =
      if Map.has_key?(state, :rtp_started) do
        []
      else
        [spec: spec]
      end

    {actions, Map.put(state, :rtp_started, true)}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, _payload_type, _list}, :rtp, _ctx, state) do
    Logger.warn("new_rtp_stream Unsupported stream connected")

    structure = [
      child({:fake_sink, ssrc}, Membrane.Element.Fake.Sink.Buffers),
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> get_child({:fake_sink, ssrc})
    ]

#    children = [
#      {{:fake_sink, ssrc}, Membrane.Element.Fake.Sink.Buffers}
#    ]

#    links = [
#      link(:rtp)
#      |> via_out(Pad.ref(:output, ssrc))
#      |> to({:fake_sink, ssrc})
#    ]

#    spec = %ParentSpec{children: children, links: links}
    {[spec: structure], state}
  end

  @impl true
  def handle_child_notification(notification, element, _ctx, state) do
    Logger.warn("Unknown notification: #{inspect(notification)}, el: #{element}")

    {[], state}
  end
end
