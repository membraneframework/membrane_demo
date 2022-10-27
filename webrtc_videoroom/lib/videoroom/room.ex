defmodule Videoroom.Room do
  @moduledoc false

  use GenServer

  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Message
  alias Membrane.RTC.Engine.Endpoint.WebRTC
  require Membrane.Logger

  @mix_env Mix.env()

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(room_id) do
    Membrane.Logger.info("Spawning room proces: #{inspect(self())}")

    # When running via docker without using host network we
    # have to listen at 0.0.0.0 but our packets still need
    # valid IP address in their headers. We store it under `mock_ip`.
    mock_ip = Application.fetch_env!(:membrane_videoroom_demo, :external_ip)
    external_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: mock_ip
    port_range = Application.fetch_env!(:membrane_videoroom_demo, :port_range)

    rtc_engine_options = [
      id: room_id
    ]

    integrated_turn_options = [
      ip: external_ip,
      mock_ip: mock_ip,
      ports_range: port_range
    ]

    network_options = [
      integrated_turn_options: integrated_turn_options,
      dtls_pkey: Application.get_env(:membrane_videoroom_demo, :dtls_pkey),
      dtls_cert: Application.get_env(:membrane_videoroom_demo, :dtls_cert)
    ]

    {:ok, pid} = Membrane.RTC.Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    {:ok, %{rtc_engine: pid, peer_channels: %{}, network_options: network_options}}
  end

  @impl true
  def handle_info({:add_peer_channel, peer_channel_pid, peer_id}, state) do
    state = put_in(state, [:peer_channels, peer_id], peer_channel_pid)
    Process.monitor(peer_channel_pid)
    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.MediaEvent{to: :broadcast, data: data}, state) do
    for {_peer_id, pid} <- state.peer_channels, do: send(pid, {:media_event, data})

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.MediaEvent{to: to, data: data}, state) do
    if state.peer_channels[to] != nil do
      send(state.peer_channels[to], {:media_event, data})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.NewPeer{rtc_engine: rtc_engine, peer: peer}, state) do
    Membrane.Logger.info("New peer: #{inspect(peer)}. Accepting.")
    # get node the peer with peer_id is running on
    peer_channel_pid = Map.get(state.peer_channels, peer.id)
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
      rtc_engine: rtc_engine,
      ice_name: peer.id,
      extensions: %{},
      owner: self(),
      integrated_turn_options: state.network_options[:integrated_turn_options],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer.id]
    }

    Engine.accept_peer(rtc_engine, peer.id)

    :ok =
      Engine.add_endpoint(rtc_engine, endpoint,
        peer_id: peer.id,
        node: peer_node
      )

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.PeerLeft{peer: peer}, state) do
    Membrane.Logger.info("Peer #{inspect(peer.id)} left RTC Engine")
    {:noreply, state}
  end

  @impl true
  def handle_info({:media_event, _from, _event} = msg, state) do
    Engine.receive_media_event(state.rtc_engine, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    if pid == state.rtc_engine do
      {:stop, :normal, state}
    else
      {peer_id, _peer_channel_id} =
        state.peer_channels
        |> Enum.find(fn {_peer_id, peer_channel_pid} -> peer_channel_pid == pid end)

      Engine.remove_peer(state.rtc_engine, peer_id)
      {_elem, state} = pop_in(state, [:peer_channels, peer_id])
      {:noreply, state}
    end
  end
end
