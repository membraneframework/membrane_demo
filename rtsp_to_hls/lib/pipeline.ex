defmodule Membrane.Demo.RtspToHls.Pipeline do
  @moduledoc """
  The pipeline, which converts the RTP stream to HLS.
  """
  use Membrane.Pipeline

  require Logger

  alias Membrane.Demo.RtspToHls.ConnectionManager
  alias Membrane.Pad

  @impl true
  def handle_init(_context, options) do
    Logger.debug("Source handle_init options: #{inspect(options)}")

    spec = [
      child(:source, %Membrane.RTSP.Source{
        transport: :tcp,
        allowed_media_types: [:video],
        stream_uri: options.stream_url
      }),
      child(
        :hls,
        %Membrane.HTTPAdaptiveStream.SinkBin{
          target_window_duration: Membrane.Time.seconds(120),
          manifest_module: Membrane.HTTPAdaptiveStream.HLS,
          storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
            directory: options.output_path
          }
        }
      )
    ]

    # connection_manager_spec = [
    #   %{
    #     id: "ConnectionManager",
    #     start:
    #       {ConnectionManager, :start_link,
    #        [
    #          [
    #            stream_url: options.stream_url,
    #            port: options.port,
    #            pipeline: self()
    #          ]
    #        ]},
    #     restart: :transient
    #   }
    # ]

    # Supervisor.start_link(connection_manager_spec,
    #   strategy: :one_for_one,
    #   name: Membrane.Demo.RtspToHls.Supervisor
    # )

    {[spec: spec],
     %{
       video: nil,
       port: options.port,
       output_path: options.output_path,
       parent_pid: options.parent_pid
     }}

    # {[spec: spec], options}
  end

  # @impl true
  # def handle_info({:rtsp_setup_complete, options}, _ctx, state) do
  #   Logger.debug("Source received pipeline options: #{inspect(options)}")

  #   structure = [
  #     child(
  #       :app_source,
  #       %Membrane.UDP.Source{
  #         local_port_no: state[:port],
  #         recv_buffer_size: 500_000
  #       }
  #     )
  #     |> via_in(:rtp_input)
  #     |> child(
  #       :rtp,
  #       %Membrane.RTP.SessionBin{
  #         fmt_mapping: %{96 => {:H264, 90_000}}
  #       }
  #     ),
  #     child(
  #       :hls,
  #       %Membrane.HTTPAdaptiveStream.SinkBin{
  #         target_window_duration: Membrane.Time.seconds(120),
  #         manifest_module: Membrane.HTTPAdaptiveStream.HLS,
  #         storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
  #           directory: state[:output_path]
  #         }
  #       }
  #     )
  #   ]

  #   {[spec: structure], %{state | video: %{sps: options[:sps], pps: options[:pps]}}}
  # end

  @impl true
  def handle_child_notification({:new_track, ssrc, track}, :source, _ctx, state) do
    Logger.debug(":new_rtp_stream")
    IO.inspect(track, label: "track")

    {spss, ppss} =
      case track.fmtp.sprop_parameter_sets do
        nil -> {[], []}
        parameter_sets -> {parameter_sets.sps, parameter_sets.pps}
      end

    # spss =
    #   case state.video.sps do
    #     <<>> -> []
    #     sps -> [sps]
    #   end

    # ppss =
    #   case state.video.pps do
    #     <<>> -> []
    #     pps -> [pps]
    #   end
    # spss = []
    # ppss = []

    structure =
      get_child(:source)
      |> via_out(
        Pad.ref(:output, ssrc)
        # options: [depayloader: Membrane.RTP.H264.Depayloader]
      )
      # |> child(:depayloader, Membrane.RTP.H264.Depayloader)
      |> child(
        :video_nal_parser,
        %Membrane.H264.Parser{
          spss: spss,
          ppss: ppss,
          generate_best_effort_timestamps: %{framerate: {30, 1}}
        }
      )
      |> via_in(:input, options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)])
      |> get_child(:hls)

    actions =
      if Map.has_key?(state, :rtp_started) do
        []
      else
        [spec: structure]
      end

    {actions, Map.put(state, :rtp_started, true)}
  end

  @impl true
  def handle_child_notification({:new_track, ssrc, _track}, :source, _ctx, state) do
    Logger.warning("new_rtp_stream Unsupported stream connected")

    structure =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> child({:fake_sink, ssrc}, Membrane.Element.Fake.Sink.Buffers)

    {[spec: structure], state}
  end

  @impl true
  def handle_child_notification({:track_playable, _ref}, :hls, _ctx, state) do
    send(state.parent_pid, :track_playable)
    {[], state}
  end

  @impl true
  def handle_child_notification(notification, element, _ctx, state) do
    Logger.warning("Unknown notification: #{inspect(notification)}, el: #{inspect(element)}")

    {[], state}
  end
end
