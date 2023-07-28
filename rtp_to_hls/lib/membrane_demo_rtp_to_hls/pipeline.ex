defmodule Membrane.Demo.RtpToHls.Pipeline do
  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_ctx, port) do
    spec = [
      child(:app_source, %Membrane.UDP.Source{
        local_port_no: port,
        recv_buffer_size: 500_000
      })
      |> via_in(Pad.ref(:rtp_input, make_ref()))
      |> child(:rtp, Membrane.RTP.SessionBin),
      child(:hls, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: Membrane.Time.seconds(10),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      })
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, 96, _ext}, :rtp, _ctx, state) do
    spec =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.H264.Depayloader])
      |> child(:video_nal_parser, %Membrane.H264.FFmpeg.Parser{
        framerate: {30, 1},
        alignment: :au,
        attach_nalus?: true
      })
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:hls)

    {[spec: spec], state}
  end

  def handle_child_notification({:new_rtp_stream, ssrc, 127, _ext}, :rtp, _ctx, state) do
    spec =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc), options: [depayloader: Membrane.RTP.AAC.Depayloader])
      |> via_in(Pad.ref(:input, :audio),
        options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:hls)

    {[spec: spec], state}
  end

  def handle_child_notification({:new_rtp_stream, ssrc, _payload_type, _ext}, :rtp, _ctx, state) do
    Logger.warning("Unsupported stream connected")

    spec =
      get_child(:rtp)
      |> via_out(Pad.ref(:output, ssrc))
      |> child({:fake_sink, ssrc}, Membrane.Fake.Sink.Buffers)

    {[spec: spec], state}
  end

  def handle_child_notification(_notification, _element, _ctx, state) do
    {[], state}
  end
end
