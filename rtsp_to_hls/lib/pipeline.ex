defmodule Membrane.Demo.RTSPToHLS.Pipeline do
  @moduledoc """
  The pipeline, which converts the RTP stream to HLS.
  """
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_context, options) do
    Logger.debug("Source handle_init options: #{inspect(options)}")

    spec = [
      child(:source, %Membrane.RTSP.Source{
        transport: {:udp, options.port, options.port + 5},
        allowed_media_types: [:video, :audio],
        stream_uri: options.stream_url,
        on_connection_closed: :send_eos
      })
    ]

    {[spec: spec],
     %{
       output_path: options.output_path,
       parent_pid: options.parent_pid,
       tracks_left_to_link: nil,
       track_specs: []
     }}
  end

  @impl true
  def handle_child_notification({:set_up_tracks, tracks}, :source, _ctx, state) do
    tracks_left_to_link =
      [:audio, :video]
      |> Enum.filter(fn media_type -> Enum.any?(tracks, &(&1.type == media_type)) end)

    {[], %{state | tracks_left_to_link: tracks_left_to_link}}
  end

  @impl true
  def handle_child_notification({:new_track, ssrc, track}, :source, _ctx, state) do
    if Enum.member?(state.tracks_left_to_link, track.type) do
      tracks_left_to_link = List.delete(state.tracks_left_to_link, track.type)
      track_specs = [get_track_spec(ssrc, track) | state.track_specs]

      spec_action =
        if tracks_left_to_link == [] do
          [
            spec: [
              child(:hls, %Membrane.HTTPAdaptiveStream.SinkBin{
                target_window_duration: Membrane.Time.seconds(120),
                manifest_module: Membrane.HTTPAdaptiveStream.HLS,
                storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{
                  directory: state.output_path
                }
              })
              | track_specs
            ]
          ]
        else
          []
        end

      {spec_action, %{state | track_specs: track_specs, tracks_left_to_link: tracks_left_to_link}}
    else
      Logger.warning("Unsupported stream connected")

      spec =
        get_child(:source)
        |> via_out(Pad.ref(:output, ssrc))
        |> child({:fake_sink, ssrc}, Membrane.Debug.Sink)

      {[spec: spec], state}
    end
  end

  @impl true
  def handle_child_notification({:track_playable, _ref}, :hls, _ctx, state) do
    send(state.parent_pid, :track_playable)
    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _element, _ctx, state) do
    {[], state}
  end

  defp get_track_spec(ssrc, track) do
    encoding =
      case track do
        %{type: :audio} -> :AAC
        %{type: :video} -> :H264
      end

    get_child(:source)
    |> via_out(Pad.ref(:output, ssrc))
    |> via_in(:input,
      options: [encoding: encoding, segment_duration: Membrane.Time.seconds(4)]
    )
    |> get_child(:hls)
  end
end
