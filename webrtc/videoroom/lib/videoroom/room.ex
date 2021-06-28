defmodule Membrane.Room do
  @moduledoc false

  use GenServer

  require Membrane.Logger

  def start(opts) do
    GenServer.start(__MODULE__, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(room_id: room_id) do
    sfu_options = [
      id: room_id,
      extension_options: [
        vad: true
      ],
      network_options: [
        stun_servers: [
          %{server_addr: "stun.l.google.com", server_port: 19_302}
        ],
        turn_servers: []
      ]
    ]

    {:ok, pid} = Membrane.SFU.start(sfu_options, [])
    send(pid, {:register, self()})
    {:ok, %{sfu_engine: pid}}
  end

  def handle_other({:sfu_media_event, to, event}, _ctx, state) do
    send(to, {:media_event, event})
    {:ok, state}
  end

  def handle_other({:media_event, _from, _event} = msg, _ctx, state) do
    send(state.sfu_engine, msg)
    {:ok, state}
  end

  def handle_other({:new_peer, peer_id, _metadata, _track_metadata}, _ctx, state) do
    send(state.sfu_engine, {:accept_new_peer, peer_id})
    {:ok, state}
  end
end
