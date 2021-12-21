defmodule Videoroom.Room do
  @moduledoc false

  use GenServer

  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.RTC.Engine
  require Membrane.Logger

  @mix_env Mix.env()

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def add_peer_channel(room, peer_channel_pid, peer_id) do
    GenServer.call(room, {:add_peer_channel, peer_channel_pid, peer_id})
  end

  @impl true
  def init(room_id) do
    Membrane.Logger.info("Spawning room process: #{inspect(self())}")

    turn_mock_ip = Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_ip)
    turn_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: turn_mock_ip

    rtc_engine_options = [
      id: room_id
    ]

    network_options = [
      stun_servers: Application.fetch_env!(:membrane_videoroom_demo, :stun_servers),
      turn_servers: Application.fetch_env!(:membrane_videoroom_demo, :turn_servers),
      integrated_turn_options: [
        use_integrated_turn:
          Application.fetch_env!(:membrane_videoroom_demo, :use_integrated_turn),
        ip: turn_ip,
        mock_ip: turn_mock_ip,
        ports_range: Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_port_range)
      ],
      dtls_pkey: Application.get_env(:membrane_videoroom_demo, :dtls_pkey),
      dtls_cert: Application.get_env(:membrane_videoroom_demo, :dtls_cert)
    ]

    {:ok, pid} = Membrane.RTC.Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())

    {:ok, %{rtc_engine: pid, peer_channels: %{}, network_options: network_options}}
  end

  @impl true
  def handle_call({:add_peer_channel, peer_channel_pid, peer_id}, _from, state) do
    state = put_in(state, [:peer_channels, peer_id], peer_channel_pid)
    Process.monitor(peer_channel_pid)
    {:reply, :ok, state}
  end

  @impl true
  def handle_info({_rtc_engine, {:rtc_media_event, :broadcast, event}}, state) do
    for {_peer_id, pid} <- state.peer_channels, do: send(pid, {:media_event, event})

    {:noreply, state}
  end

  @impl true
  def handle_info({_rtc_engine, {:rtc_media_event, to, event}}, state) do
    if state.peer_channels[to] != nil do
      send(state.peer_channels[to], {:media_event, event})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({rtc_engine, {:new_peer, peer_id, _metadata}}, state) do
    peer_channel_pid = Map.get(state.peer_channels, peer_id)
    peer_node = node(peer_channel_pid)

    handshake_opts =
      if state.network_options[:dtls_pkey] &&
           state.network_options[:dtls_cert] do
        [
          client_mode: false,
          dtls_srtp: true,
          pkey: state.network_options[:dtls_pkey],
          cert: state.network_options[:dtls_cert]
        ]
      else
        [
          client_mode: false,
          dtls_srtp: true
        ]
      end

    endpoint = %WebRTC{
      ice_name: peer_id,
      owner: self(),
      stun_servers: state.network_options[:stun_servers] || [],
      turn_servers: state.network_options[:turn_servers] || [],
      integrated_turn_options: state.network_options[:integrated_turn_options],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer_id]
    }

    Engine.accept_peer(rtc_engine, peer_id)
    Engine.add_endpoint(rtc_engine, endpoint, peer_id: peer_id, node: peer_node)

    {:noreply, state}
  end

  @impl true
  def handle_info({_sfu_engine, {:peer_left, _peer_id}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:media_event, _from, _event} = msg, state) do
    Engine.receive_media_event(state.rtc_engine, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {peer_id, _peer_channel_id} =
      state.peer_channels
      |> Enum.find(fn {_peer_id, peer_channel_pid} -> peer_channel_pid == pid end)

    Engine.send_remove_peer(state.rtc_engine, peer_id)
    {_elem, state} = pop_in(state, [:peer_channels, peer_id])
    {:noreply, state}
  end
end
