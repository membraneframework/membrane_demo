defmodule VideoRoom.Stream.Pipeline do
  use Membrane.Pipeline

  require Membrane.Logger

  def start_link() do
    Membrane.Pipeline.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def handle_init(_opts) do
    play(self())
    {:ok, %{:peers => -1}}
  end

  @impl true
  def handle_other({:new_peer, ws_pid}, ctx, state) do
    if Map.has_key?(ctx.children, {:endpoint, ws_pid}) do
      Membrane.Logger.warn("Peer already connected, ignoring")
      {:ok, state}
    else
      state = %{state | peers: state.peers + 1}
      Membrane.Logger.info("New peer #{inspect(ws_pid)}, peers: #{inspect(state.peers)}")
      endpoint = {:endpoint, ws_pid}
      children = %{endpoint => %VideoRoom.Stream.WebRTCEndpoint{initial_peers: state.peers}}

      [links, ice_restarts] =
        Enum.reduce(Map.keys(ctx.children), [[], []], fn
          {:tee, _id, encoding} = tee, [links, ice_restarts] ->
            links =
              links ++
                [link(tee) |> via_in(:input, options: [encoding: encoding]) |> to(endpoint)]

            [links, ice_restarts]

          {:endpoint, _ws_pid} = endpoint, [links, ice_restarts] ->
            ice_restarts = ice_restarts ++ [forward: {endpoint, {:restart_ice, state.peers}}]
            [links, ice_restarts]

          _child, acc ->
            acc
        end)

      spec = %ParentSpec{children: children, links: links}
      {{:ok, [spec: spec] ++ ice_restarts}, %{state | peers: state.peers}}
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
