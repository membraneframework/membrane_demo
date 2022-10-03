defmodule Membrane.Demo.RTP.ReceivePipeline do
  use Membrane.Pipeline

  require Logger

  alias Membrane.{H264, Opus, RTP, UDP}

  @impl true
  def handle_init(opts) do
    %{audio_port: audio_port, video_port: video_port, secure?: secure?, srtp_key: srtp_key} = opts

    spec = %ParentSpec{
      children: [
        video_src: %UDP.Source{
          local_port_no: video_port,
          local_address: {127, 0, 0, 1}
        },
        audio_src: %UDP.Source{
          local_port_no: audio_port,
          local_address: {127, 0, 0, 1}
        },
        rtp: %RTP.SessionBin{
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
        }
      ],
      links: [
        link(:video_src) |> via_in(:rtp_input) |> to(:rtp),
        link(:audio_src) |> via_in(:rtp_input) |> to(:rtp)
      ]
    }

    {{:ok, spec: spec, playback: :playing}, %{}}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 96, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :video, ssrc)
    actions = handle_stream(state)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 120, _extensions}, :rtp, _ctx, state) do
    state = Map.put(state, :audio, ssrc)
    actions = handle_stream(state)
    {{:ok, actions}, state}
  end

  @impl true
  def handle_notification(
        {:new_rtp_stream, _ssrc, encoding_name, _extensions},
        :rtp,
        _ctx,
        _state
      ) do
    raise "Unsupported encoding: #{inspect(encoding_name)}"
  end

  @impl true
  def handle_notification({:connection_info, {127, 0, 0, 1}, _port}, :audio_src, _ctx, state) do
    Logger.info("Audio UDP source connected.")
    {:ok, state}
  end

  @impl true
  def handle_notification({:connection_info, {127, 0, 0, 1}, _port}, :video_src, _ctx, state) do
    Logger.info("Video UDP source connected.")
    {:ok, state}
  end

  defp handle_stream(%{audio: audio_ssrc, video: video_ssrc}) do
    spec = %ParentSpec{
      children: %{
        audio_decoder: Opus.Decoder,
        audio_player: Membrane.PortAudio.Sink,
        video_parser: %H264.FFmpeg.Parser{framerate: {30, 1}},
        video_decoder: H264.FFmpeg.Decoder,
        video_player: Membrane.SDL.Player
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, video_ssrc),
          options: [depayloader: RTP.H264.Depayloader]
        )
        |> to(:video_parser)
        |> to(:video_decoder)
        |> to(:video_player),
        #
        link(:rtp)
        |> via_out(Pad.ref(:output, audio_ssrc),
          options: [depayloader: RTP.Opus.Depayloader]
        )
        |> to(:audio_decoder)
        |> to(:audio_player)
      ],
      stream_sync: :sinks
    }

    [spec: spec]
  end

  defp handle_stream(_state) do
    []
  end
end
