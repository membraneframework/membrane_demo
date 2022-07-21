defmodule Membrane.Demo.RtspToHls.Pipeline do
  @moduledoc """
  The pipeline, which converts the RTP stream to HLS.
  """
  use Membrane.Pipeline

  require Logger

  alias Membrane.Demo.RtspToHls.{ConnectionManager, Stream}

  @rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"

  @impl true
  def handle_init(options) do
    Logger.debug("Source handle_init options: #{inspect(options)}")

    connection_children = [
      {Registry, keys: :unique, name: Membrane.Demo.RtspToHls.Registry},
      %{
        id: "ConnectionManager",
        start:
          {ConnectionManager, :start_link,
           [
             [
               stream: %Stream{
                 stream_url: @rtsp_stream_url,
                 path: Application.fetch_env!(:hls_proxy_api, :hls_path)
               },
               pipeline: self()
             ]
           ]},
        restart: :transient
      }
    ]

    Supervisor.start_link(connection_children,
      strategy: :one_for_one,
      name: Membrane.Demo.RtspToHls.Supervisor
    )

    # Supervisor.start_link(
    #   __MODULE__,
    #   [
    #     stream: %Stream{
    #       stream_url: @rtsp_stream_url,
    #       path: Application.fetch_env!(:hls_proxy_api, :hls_path)
    #     },
    #     pipeline: self()
    #   ],
    #   name: __MODULE__
    # )

    {:ok, %{video: nil}}
  end

  @impl true
  def handle_other({:pipeline_options, options}, _ctx, state) do
    Logger.debug("Source received pipeline options: #{inspect(options)}")

    children = %{
      app_source: %Membrane.UDP.Source{
        local_port_no: options[:port],
        recv_buffer_size: 500_000
      },
      rtp: %Membrane.RTP.SessionBin{
        fmt_mapping: %{96 => {:H264, 90_000}}
      },
      hls: %Membrane.HTTPAdaptiveStream.Sink{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 10 |> Membrane.Time.seconds(),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
          directory: options[:output_path]
        }
      }
    }

    links = [
      link(:app_source)
      |> via_in(Pad.ref(:rtp_input, make_ref()))
      |> to(:rtp)
    ]

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, %{state | video: %{sps: options[:sps], pps: options[:pps]}}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 96, _extensions}, :rtp, _ctx, state) do
    Logger.debug(":new_rtp_stream")

    children = %{
      video_nal_parser: %Membrane.H264.FFmpeg.Parser{
        sps: state.video.sps,
        pps: state.video.pps,
        skip_until_keyframe?: true,
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      },
      video_payloader: Membrane.MP4.Payloader.H264,
      video_cmaf_muxer: Membrane.MP4.Muxer.CMAF
    }

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:output, ssrc),
        options: [depayloader: Membrane.RTP.H264.Depayloader]
      )
      |> to(:video_nal_parser)
      |> to(:video_payloader)
      |> to(:video_cmaf_muxer)
      |> via_in(:input)
      |> to(:hls)
    ]

    spec = %ParentSpec{children: children, links: links}

    actions =
      if Map.has_key?(state, :rtp_started) do
        []
      else
        [spec: spec]
      end

    {{:ok, actions}, Map.put(state, :rtp_started, true)}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, _payload_type, _list}, :rtp, _ctx, state) do
    Logger.warn("new_rtp_stream Unsupported stream connected")

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

  @impl true
  def handle_notification(notification, element, _ctx, state) do
    Logger.warn("Unknown notification: #{inspect(notification)}, el: #{element}")

    {:ok, state}
  end
end
