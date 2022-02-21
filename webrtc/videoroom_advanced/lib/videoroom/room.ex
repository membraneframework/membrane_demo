defmodule Videoroom.Room do
  @moduledoc false

  use GenServer

  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Message
  alias Membrane.RTC.Engine.Endpoint.WebRTC
  alias Membrane.ICE.TURNManager
  require Membrane.Logger
  require OpenTelemetry.Tracer, as: Tracer

  @mix_env Mix.env()

  def start(init_arg, opts) do
    GenServer.start(__MODULE__, init_arg, opts)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(room_id) do
    Membrane.Logger.info("Spawning room process: #{inspect(self())}")

    turn_mock_ip = Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_ip)
    turn_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: turn_mock_ip

    trace_ctx = create_context("room:#{room_id}")

    rtc_engine_options = [
      id: room_id,
      trace_ctx: trace_ctx
    ]

    use_integrated_turn = Application.fetch_env!(:membrane_videoroom_demo, :use_integrated_turn)

    turn_cert_file =
      case Application.fetch_env(:membrane_videoroom_demo, :integrated_turn_cert_pkey) do
        {:ok, val} -> val
        :error -> nil
      end

    integrated_turn_options = [
      ip: turn_ip,
      mock_ip: turn_mock_ip,
      ports_range: Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_port_range),
      cert_file: turn_cert_file
    ]

    network_options = [
      stun_servers: Application.fetch_env!(:membrane_videoroom_demo, :stun_servers),
      turn_servers: Application.fetch_env!(:membrane_videoroom_demo, :turn_servers),
      use_integrated_turn: use_integrated_turn,
      integrated_turn_options: integrated_turn_options,
      integrated_turn_domain:
        Application.fetch_env!(:membrane_videoroom_demo, :integrated_turn_domain),
      dtls_pkey: Application.get_env(:membrane_videoroom_demo, :dtls_pkey),
      dtls_cert: Application.get_env(:membrane_videoroom_demo, :dtls_cert)
    ]

    if use_integrated_turn do
      tcp_turn_port = Application.get_env(:membrane_videoroom_demo, :integrated_tcp_turn_port)
      TURNManager.ensure_tcp_turn_launched(integrated_turn_options, port: tcp_turn_port)

      if turn_cert_file do
        tls_turn_port = Application.get_env(:membrane_videoroom_demo, :integrated_tls_turn_port)
        TURNManager.ensure_tls_turn_launched(integrated_turn_options, port: tls_turn_port)
      end
    end

    {:ok, pid} = Membrane.RTC.Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    {:ok,
     %{
       rtc_engine: pid,
       peer_channels: %{},
       network_options: network_options,
       trace_ctx: trace_ctx
     }}
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
      ice_name: peer.id,
      owner: self(),
      stun_servers: state.network_options[:stun_servers] || [],
      turn_servers: state.network_options[:turn_servers] || [],
      use_integrated_turn: state.network_options[:use_integrated_turn],
      integrated_turn_options: state.network_options[:integrated_turn_options],
      integrated_turn_domain: state.network_options[:integrated_turn_domain],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer.id],
      trace_context: state.trace_ctx
    }

    Engine.accept_peer(rtc_engine, peer.id)
    :ok = Engine.add_endpoint(rtc_engine, endpoint, peer_id: peer.id, node: peer_node)

    counter = Map.get(state, :counter, 0)

    if counter == 2 do
      Process.send_after(self(), :end_engine, 15_000)
    end

    state = Map.put(state, :counter, counter + 1)

    {:noreply, state}
  end

  @impl true
  def handle_info(:end_engine, state) do
    Engine.stop_and_terminate(state.rtc_engine)
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

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp create_context(name) do
    metadata = [
      {:"library.language", :erlang},
      {:"library.name", :membrane_rtc_engine},
      {:"library.version", "server:#{Application.spec(:membrane_rtc_engine, :vsn)}"}
    ]

    root_span = Tracer.start_span(name)
    parent_ctx = Tracer.set_current_span(root_span)
    otel_ctx = OpenTelemetry.Ctx.attach(parent_ctx)
    OpenTelemetry.Span.set_attributes(root_span, metadata)
    OpenTelemetry.Span.end_span(root_span)
    OpenTelemetry.Ctx.attach(otel_ctx)

    otel_ctx
  end
end
