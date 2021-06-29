defmodule Membrane.Room do
  @moduledoc false

  use GenServer

  require Membrane.Logger

  def start(opts) do
    GenServer.start(__MODULE__, [], opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(opts) do
    Membrane.Logger.info("Spawning room proces: #{inspect(self())}")

    sfu_options = [
      id: opts[:room_id],
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

  @impl true
  def handle_info({_sfu_engine, {:sfu_media_event, :broadcast, event}}, state) do
    Registry.dispatch(Membrane.PeerChannel.Registry, :peer_channel, fn entries ->
      for {pid, _value} <- entries, do: send(pid, {:media_event, event})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({_sfu_engine, {:sfu_media_event, to, event}}, state) do
    [{pid, _value}] = Registry.match(Membrane.PeerChannel.Registry, :peer_channel, to)
    send(pid, {:media_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_info({_sfu_engine, {:new_peer, peer_id, _metadata, _track_metadata}}, state) do
    send(state.sfu_engine, {:accept_new_peer, peer_id})
    {:noreply, state}
  end

  @impl true
  def handle_info({:media_event, _from, _event} = msg, state) do
    send(state.sfu_engine, msg)
    {:noreply, state}
  end
end
