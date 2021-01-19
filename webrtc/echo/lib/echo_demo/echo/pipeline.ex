defmodule EchoDemo.Echo.Pipeline do
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
    endpoint = {:endpoint, ws_pid}
    children = %{endpoint => WebRTCEndpoint}

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

  @impl true
  def handle_other({:event, ws_pid, event}, _ctx, state) do
    {{:ok, forward: {{:endpoint, ws_pid}, {:event, event}}}, state}
  end

  @impl true
  def handle_notification({:new_stream, encoding, output_id}, endpoint, ctx, state) do
    tee = {:tee, output_id, encoding}
    children = %{tee => Membrane.Element.Tee.Parallel}

    links =
      [link(endpoint) |> via_out(Pad.ref(:output, output_id)) |> to(tee)] ++
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
    send(ws_pid, message)
    {:ok, state}
  end
end
