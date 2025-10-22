defmodule Membrane.Demo.RTSPToHLS.Pipeline do
  @moduledoc """
  The pipeline which converts the stream to HLS.
  """
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_context, options) do
    spec = [
      child(:source, %Membrane.RTSP.Source{
        transport: {:udp, options.port, options.port + 5},
        allowed_media_types: [:video, :audio],
        stream_uri: options.stream_url,
        on_connection_closed: :send_eos
      }),
      child(:hls, %Membrane.HTTPAdaptiveStream.SinkBin{
        target_window_duration: Membrane.Time.seconds(120),
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
          directory: options.output_path
        }
      })
    ]

    {[spec: spec], %{parent_pid: options.parent_pid}}
  end

  @impl true
  def handle_child_notification({:set_up_tracks, tracks}, :source, _ctx, state) do
    track_specs =
      Enum.uniq_by(tracks, & &1.type)
      |> Enum.filter(&(&1.type in [:audio, :video]))
      |> Enum.map(fn track ->
        encoding =
          case track do
            %{type: :audio} -> :AAC
            %{type: :video} -> :H264
          end

        get_child(:source)
        |> via_out(Pad.ref(:output, track.control_path))
        |> via_in(:input,
          options: [encoding: encoding, segment_duration: Membrane.Time.seconds(4)]
        )
        |> get_child(:hls)
      end)

    {[spec: track_specs], state}
  end

  @impl true
  def handle_child_notification({:track_playable, _ref}, :hls, _ctx, state) do
    send(state.parent_pid, :track_playable)
    {[], state}
  end

  @impl true
  def handle_child_notification(notification, _element, _ctx, state) do
    Logger.warning("Ignoring notification #{notification}")
    {[], state}
  end
end
