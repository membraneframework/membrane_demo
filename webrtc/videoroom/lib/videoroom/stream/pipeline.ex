defmodule VideoRoom.Stream.Pipeline do
  use Membrane.Pipeline

  require Membrane.Logger

  def start_link() do
    Membrane.Pipeline.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def handle_init(_opts) do
    play(self())
    {:ok, %{}}
  end

  @impl true
  def handle_other({:new_peer, ws_pid}, ctx, state) do
    if Map.has_key?(ctx.children, {:endpoint, ws_pid}) do
      Membrane.Logger.warn("Peer already connected, ignoring")
      {:ok, state}
    else
      Membrane.Logger.info("New peer #{inspect(ws_pid)}")
      endpoint = {:endpoint, ws_pid}
      children = %{endpoint => VideoRoom.Stream.WebRTCEndpoint}

      links =
        Enum.flat_map(Map.keys(ctx.children), fn
          {:tee, _id, encoding} = tee ->
            [link(tee) |> via_in(:input, options: [encoding: encoding]) |> to(endpoint)]

          _child ->
            []
        end)

      spec = %ParentSpec{children: children, links: links}
      {{:ok, spec: spec}, state}
    end
  end

  @impl true
  def handle_other({:signal, ws_pid, msg}, _ctx, state) do
    {{:ok, forward: {{:endpoint, ws_pid}, {:signal, msg}}}, state}
  end

  @impl true
  def handle_notification({:new_stream, encoding, output_id}, endpoint, ctx, state) do
    Membrane.Logger.info("New incoming RTP #{encoding} stream")
    tee = {:tee, output_id, encoding}
    fake = {:fake, output_id}
    children = %{tee => Membrane.Element.Tee.Parallel, fake => Membrane.Element.Fake.Sink.Buffers}

    links =
      [link(endpoint) |> via_out(Pad.ref(:output, output_id)) |> to(tee), link(tee) |> to(fake)] ++
        Enum.flat_map(Map.keys(ctx.children), fn
          ^endpoint ->
            []

          {:endpoint, _id} = other_endpoint ->
            [link(tee) |> via_in(:input, options: [encoding: encoding]) |> to(other_endpoint)]

          _child ->
            []
        end)

    spec = %ParentSpec{children: children, links: links}
    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:signal, message}, {:endpoint, ws_pid}, _ctx, state) do
    VideoRoom.WS.signal(ws_pid, message)
    {:ok, state}
  end
end
