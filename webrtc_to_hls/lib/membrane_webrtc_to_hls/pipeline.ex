defmodule Membrane.Demo.WebRTCToHLS.Pipeline do
  use Membrane.Pipeline

  alias Membrane.WebRTC.{EndpointBin, Track}

  require Membrane.Logger

  @pipeline_registry Membrane.Demo.WebRTCToHLS.PipelineRegistry

  def registry(), do: @pipeline_registry

  def lookup(owner_pid) do
    case Registry.lookup(@pipeline_registry, owner_pid) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  def start_link(owner_pid) do
    do_start(:start_link, owner_pid)
  end

  def start(owner_pid) do
    do_start(:start, owner_pid)
  end

  defp do_start(func, owner_pid) when func in [:start, :start_link] do
    Membrane.Logger.info(
      "[WebRTCToHLS.Pipeline] Starting pipeline for owner #{inspect(owner_pid)}"
    )

    apply(Membrane.Pipeline, func, [
      __MODULE__,
      [owner_pid],
      [name: {:via, Registry, {@pipeline_registry, owner_pid}}]
    ])
  end

  @impl true
  def handle_init([owner_pid]) do
    Process.monitor(owner_pid)

    play(self())
    {:ok, %{owner: owner_pid}}
  end

  @impl true
  def handle_other(:start, _ctx, %{owner: owner} = state) do
    stream_id = Track.stream_id()
    tracks = [Track.new(:audio, stream_id), Track.new(:video, stream_id)]

    directory = owner_directory(owner)
    File.rm_rf(directory)
    File.mkdir!(directory)

    Membrane.Logger.info(
      "[WebRTCToHLS.Pipeline] Created output directory '#{directory}' for owner #{inspect(owner)}"
    )

    children = %{
      endpoint: %EndpointBin{
        outbound_tracks: [],
        inbound_tracks: tracks
      },
      hls: %Membrane.HTTPAdaptiveStream.Sink{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: 10 |> Membrane.Time.seconds(),
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: directory}
      }
    }

    spec = %ParentSpec{children: children, links: []}
    {{:ok, [spec: spec]}, state}
  end

  @impl true
  def handle_other({:signal, msg}, _ctx, state) do
    {{:ok, forward: {:endpoint, {:signal, msg}}}, state}
  end

  def handle_other(:stop, _ctx, state) do
    Membrane.Pipeline.stop_and_terminate(self())
    {:ok, state}
  end

  @impl true
  def handle_other({:DOWN, _ref, :process, owner, _reason}, _ctx, %{owner: owner} = state) do
    Membrane.Pipeline.stop_and_terminate(self())
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_track, track_id, encoding}, _endpoint, _ctx, state) do
    %{children: hls_children, links: hls_links} =
      case encoding do
        :H264 ->
          %{
            children: %{
              video_parser: %Membrane.H264.FFmpeg.Parser{
                framerate: {30, 1},
                alignment: :au,
                attach_nalus?: true
              },
              video_payloader: Membrane.MP4.Payloader.H264,
              video_cmaf_muxer: Membrane.MP4.CMAF.Muxer
            },
            links: [
              link(:endpoint)
              |> via_out(Pad.ref(:output, track_id))
              |> to(:video_parser)
              |> to(:video_payloader)
              |> to(:video_cmaf_muxer)
              |> via_in(:input)
              |> to(:hls)
            ]
          }

        :OPUS ->
          %{
            children: %{
              opus_decoder: Membrane.Opus.Decoder,
              aac_encoder: Membrane.AAC.FDK.Encoder,
              aac_parser: %Membrane.AAC.Parser{out_encapsulation: :none},
              audio_payloader: Membrane.MP4.Payloader.AAC,
              audio_cmaf_muxer: Membrane.MP4.CMAF.Muxer
            },
            links: [
              link(:endpoint)
              |> via_out(Pad.ref(:output, track_id))
              |> to(:opus_decoder)
              |> to(:aac_encoder)
              |> to(:aac_parser)
              |> to(:audio_payloader)
              |> to(:audio_cmaf_muxer)
              |> via_in(:input)
              |> to(:hls)
            ]
          }
      end

    spec = %ParentSpec{children: hls_children, links: hls_links}
    {{:ok, spec: spec}, state}
  end

  def handle_notification({:end_of_stream, _pad}, :aac_encoder, _ctx, state) do
    {:ok, state}
  end

  def handle_notification({:cleanup, _}, :hls, _ctx, %{owner: owner} = state) do
    directory = owner_directory(owner)
    File.rm_rf!(directory)
    {:ok, state}
  end

  def handle_notification({:signal, message}, :endpoint, _ctx, %{owner: owner} = state) do
    send(owner, {:signal, message})
    {:ok, state}
  end

  def handle_notification({:track_playable, _ref}, _el, _ctx, state) do
    {:ok, state}
  end

  defp pid_to_hash(pid) do
    :crypto.hash(:md5, :erlang.pid_to_list(pid)) |> Base.encode16(case: :lower)
  end

  defp owner_directory(owner_pid) do
    "output/#{pid_to_hash(owner_pid)}"
  end
end
