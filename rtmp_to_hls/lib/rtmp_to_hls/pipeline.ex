defmodule Membrane.Demo.RtmpToHls do
  use Membrane.Pipeline

  alias Membrane.RTMP.SourceBin
  import Membrane.ChildrenSpec

  @impl true
  def handle_init(_context, socket: socket) do
    #    spec = %ParentSpec{
    #      children: %{
    #        src: %SourceBin{socket: socket},
    #        sink: %Membrane.HTTPAdaptiveStream.SinkBin{
    #          manifest_module: Membrane.HTTPAdaptiveStream.HLS,
    #          target_window_duration: :infinity,
    #          muxer_segment_duration: 8 |> Membrane.Time.seconds(),
    #          persist?: false,
    #          storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
    #        }
    #      },
    #      links: [
    #        link(:src)
    #        |> via_out(:audio)
    #        |> via_in(Pad.ref(:input, :audio), options: [encoding: :AAC])
    #        |> to(:sink),
    #        link(:src)
    #        |> via_out(:video)
    #        |> via_in(Pad.ref(:input, :video), options: [encoding: :H264])
    #        |> to(:sink)
    #      ]
    #    }

    structure = [
      child(:src, %SourceBin{socket: socket})
      |> via_out(:audio)
      |> via_in(Pad.ref(:input, :audio),
        options: [encoding: :AAC, segment_duration: Membrane.Time.seconds(4)]
      )
      |> child(:sink, %Membrane.HTTPAdaptiveStream.SinkBin{
        manifest_module: Membrane.HTTPAdaptiveStream.HLS,
        target_window_duration: :infinity,
        persist?: false,
        storage: %Membrane.HTTPAdaptiveStream.Storages.FileStorage{directory: "output"}
      }),
      get_child(:src)
      |> via_out(:video)
      |> via_in(Pad.ref(:input, :video),
        options: [encoding: :H264, segment_duration: Membrane.Time.seconds(4)]
      )
      |> get_child(:sink)
    ]

    {[spec: structure], %{socket: socket}}
  end

  @impl true
  def handle_child_notification(
        {:socket_control_needed, _socket, _source} = notification,
        :src,
        _ctx,
        state
      ) do
    send(self(), notification)
    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_info({:socket_control_needed, socket, source} = notification, _ctx, state) do
    case SourceBin.pass_control(socket, source) do
      :ok ->
        :ok

      {:error, :not_owner} ->
        Process.send_after(self(), notification, 200)
    end

    {[], state}
  end
end
