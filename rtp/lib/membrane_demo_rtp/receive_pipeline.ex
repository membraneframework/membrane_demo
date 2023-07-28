defmodule Membrane.Demo.RTP.ReceivePipeline do
  use Membrane.Pipeline

  require Logger

  alias Membrane.{H264, Opus, RTP, UDP}

  @local_ip {127, 0, 0, 1}

  @impl true
  def handle_init(_ctx, opts) do
    %{audio_port: audio_port, video_port: video_port, secure?: secure?, srtp_key: srtp_key} = opts

    spec = [
      child(:video_src, %UDP.Source{
        local_port_no: video_port,
        local_address: @local_ip
      })
      |> via_in(:rtp_input)
      |> child(:rtp, %RTP.SessionBin{
        secure?: secure?,
        srtp_policies: [
          %ExLibSRTP.Policy{
            ssrc: :any_inbound,
            key: srtp_key
          }
        ],
        fmt_mapping: %{
          96 => {:H264, 90_000},
          120 => {:OPUS, 48_000}
        }
      }),
      child(:audio_src, %UDP.Source{
        local_port_no: audio_port,
        local_address: @local_ip
      })
      |> via_in(:rtp_input)
      |> get_child(:rtp)
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, 96, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :video, ssrc)
    actions = handle_stream(state)
    {actions, state}
  end

  @impl true
  def handle_child_notification({:new_rtp_stream, ssrc, 120, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :audio, ssrc)
    actions = handle_stream(state)
    {actions, state}
  end

  @impl true
  def handle_child_notification(
        {:new_rtp_stream, _ssrc, encoding_name, _extensions},
        :rtp,
        _ctx,
        _state
      ) do
    raise "Unsupported encoding: #{inspect(encoding_name)}"
  end

  @impl true
  def handle_child_notification({:connection_info, @local_ip, _port}, :audio_src, _ctx, state) do
    Logger.info("Audio UDP source connected.")
    {[], state}
  end

  @impl true
  def handle_child_notification({:connection_info, @local_ip, _port}, :video_src, _ctx, state) do
    Logger.info("Video UDP source connected.")
    {[], state}
  end

  defp handle_stream(%{audio: audio_ssrc, video: video_ssrc}) do
    spec =
      {[
         get_child(:rtp)
         |> via_out(Pad.ref(:output, video_ssrc), options: [depayloader: RTP.H264.Depayloader])
         |> child(:video_parser, %H264.FFmpeg.Parser{framerate: {30, 1}})
         |> child(:video_decoder, H264.FFmpeg.Decoder)
         |> child(:video_player, Membrane.SDL.Player),
         get_child(:rtp)
         |> via_out(Pad.ref(:output, audio_ssrc), options: [depayloader: RTP.Opus.Depayloader])
         |> child(:audio_decoder, Opus.Decoder)
         |> child(:audio_player, Membrane.PortAudio.Sink)
       ], stream_sync: :sinks}

    [spec: spec]
  end

  defp handle_stream(_state) do
    []
  end
end
