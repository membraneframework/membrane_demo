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

  def handle_other({:media_event, event, peer_channel_pid}, _ctx, state) do
    send(sfu_engine, event)
    {:ok, state}
  end

  def handle_other()
end
