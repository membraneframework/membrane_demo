defmodule VideoRoom.Stream.Pipeline do
  use Membrane.Pipeline

  alias Membrane.WebRTC.Track

  require Membrane.Logger

  def start_link() do
    Membrane.Pipeline.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def handle_init(_opts) do
    play(self())
    {:ok, %{tracks: []}}
  end

  @impl true
  def handle_other({:new_peer, ws_pid}, ctx, state) do
    if Map.has_key?(ctx.children, {:endpoint, ws_pid}) do
      Membrane.Logger.warn("Peer already connected, ignoring")
      {:ok, state}
    else
      stream_id = Track.stream_id()
      tracks = [Track.new(:audio, stream_id), Track.new(:video, stream_id)]
      Membrane.Logger.info("New peer #{inspect(ws_pid)}")
      endpoint = {:endpoint, ws_pid}

      children = %{
        endpoint => %VideoRoom.Stream.WebRTCEndpoint{
          outbound_tracks: state.tracks,
          inbound_tracks: tracks
        }
      }

      [links, ice_restarts] =
        Enum.reduce(Map.keys(ctx.children), [[], []], fn
          {:tee, id, encoding} = tee, [links, ice_restarts] ->
            links =
              links ++
                [
                  link(tee)
                  |> via_in(Pad.ref(:input, id), options: [encoding: encoding])
                  |> to(endpoint)
                ]

            [links, ice_restarts]

          {:endpoint, _ws_pid} = endpoint, [links, ice_restarts] ->
            ice_restarts = ice_restarts ++ [forward: {endpoint, {:add_tracks, tracks}}]
            [links, ice_restarts]

          _child, acc ->
            acc
        end)

      spec = %ParentSpec{children: children, links: links}
      {{:ok, [spec: spec] ++ ice_restarts}, %{state | tracks: tracks ++ state.tracks}}
    end
  end

  @impl true
  def handle_other({:signal, ws_pid, msg}, _ctx, state) do
    {{:ok, forward: {{:endpoint, ws_pid}, {:signal, msg}}}, state}
  end

  @impl true
  def handle_notification({:new_track, track_id, encoding}, endpoint, ctx, state) do
    Membrane.Logger.info("New incoming RTP #{encoding} stream")
    tee = {:tee, track_id, encoding}
    fake = {:fake, track_id}
    children = %{tee => Membrane.Element.Tee.Parallel, fake => Membrane.Element.Fake.Sink.Buffers}

    links =
      [link(endpoint) |> via_out(Pad.ref(:output, track_id)) |> to(tee), link(tee) |> to(fake)] ++
        Enum.flat_map(Map.keys(ctx.children), fn
          ^endpoint ->
            []

          {:endpoint, _id} = other_endpoint ->
            [
              link(tee)
              |> via_in(Pad.ref(:input, track_id), options: [encoding: encoding])
              |> to(other_endpoint)
            ]

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
