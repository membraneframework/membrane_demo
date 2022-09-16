defmodule Membrane.Demo.RtmpToHls do
  use Membrane.Pipeline

  alias Membrane.RTMP.SourceBin

  @impl true
  def handle_init(socket: socket) do
    IO.inspect("pipeline handle_init")

    spec = %ParentSpec{
      children: %{
        src: %SourceBin{socket: socket},
        sink: %Membrane.HTTPAdaptiveStream.SinkBin{
          manifest_module: Membrane.HTTPAdaptiveStream.HLS,
          target_window_duration: 20 |> Membrane.Time.seconds(),
          muxer_segment_duration: 8 |> Membrane.Time.seconds(),
          persist?: false,
          storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
        }
      },
      links: [
        link(:src)
        |> via_out(:audio)
        |> via_in(Pad.ref(:input, :audio), options: [encoding: :AAC])
        |> to(:sink),
        link(:src)
        |> via_out(:video)
        |> via_in(Pad.ref(:input, :video), options: [encoding: :H264])
        |> to(:sink)
      ]
    }

    {{:ok, spec: spec, playback: :playing}, %{socket: socket}}
  end

  @impl true
  def handle_notification(
        {:rtmp_source_initialized, _socket, _source} = notification,
        :src,
        _ctx,
        state
      ) do
    send(self(), notification)

    {:ok, state}
  end

  @impl true
  def handle_notification(notification, child, _ctx, state) do
    IO.inspect(notification, label: "pipeline notification")
    IO.inspect(child, label: "from child")
    {:ok, state}
  end

  @impl true
  def handle_other({:rtmp_source_initialized, socket, source} = notification, _ctx, state) do
    case SourceBin.pass_control(socket, source) do
      :ok ->
        :ok

      {:error, :not_owner} ->
        Process.send_after(self(), notification, 200)
    end

    {:ok, state}
  end
end
