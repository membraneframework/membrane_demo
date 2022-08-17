defmodule WebRTCToHLS.Stream do
  @moduledoc false

  use GenServer

  alias Membrane.RTC.Engine
  alias Membrane.RTC.Engine.Message
  alias Membrane.RTC.Engine.MediaEvent
  alias Membrane.RTC.Engine.Endpoint.{WebRTC, HLS}
  alias Membrane.ICE.TURNManager
  alias Membrane.WebRTC.Extension.{Mid, Rid}
  alias WebRTCToHLS.StorageCleanup

  require Membrane.Logger
  require OpenTelemetry.Tracer, as: Tracer

  @mix_env Mix.env()

  def start(channel_pid) do
    GenServer.start(__MODULE__, [channel_pid])
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init([channel_pid]) do
    Membrane.Logger.info("Spawning room process: #{inspect(self())}")

    turn_mock_ip = Application.fetch_env!(:membrane_webrtc_to_hls_demo, :integrated_turn_ip)
    turn_ip = if @mix_env == :prod, do: {0, 0, 0, 0}, else: turn_mock_ip

    room_id = UUID.uuid4()

    trace_ctx = create_context("room:#{room_id}")

    rtc_engine_options = [
      id: room_id,
      trace_ctx: trace_ctx,
      display_manager?: false
    ]

    turn_cert_file =
      case Application.fetch_env(:membrane_webrtc_to_hls_demo, :integrated_turn_cert_pkey) do
        {:ok, val} -> val
        :error -> nil
      end

    integrated_turn_options = [
      ip: turn_ip,
      mock_ip: turn_mock_ip,
      ports_range:
        Application.fetch_env!(:membrane_webrtc_to_hls_demo, :integrated_turn_port_range),
      cert_file: turn_cert_file
    ]

    network_options = [
      integrated_turn_options: integrated_turn_options,
      integrated_turn_domain:
        Application.fetch_env!(:membrane_webrtc_to_hls_demo, :integrated_turn_domain),
      dtls_pkey: Application.get_env(:membrane_webrtc_to_hls_demo, :dtls_pkey),
      dtls_cert: Application.get_env(:membrane_webrtc_to_hls_demo, :dtls_cert)
    ]

    tcp_turn_port = Application.get_env(:membrane_webrtc_to_hls_demo, :integrated_tcp_turn_port)
    TURNManager.ensure_tcp_turn_launched(integrated_turn_options, port: tcp_turn_port)

    if turn_cert_file do
      tls_turn_port = Application.get_env(:membrane_webrtc_to_hls_demo, :integrated_tls_turn_port)
      TURNManager.ensure_tls_turn_launched(integrated_turn_options, port: tls_turn_port)
    end

    {:ok, pid} = Membrane.RTC.Engine.start(rtc_engine_options, [])
    Engine.register(pid, self())
    Process.monitor(pid)

    endpoint = %HLS{
      rtc_engine: pid,
      owner: self(),
      output_directory:
        Application.fetch_env!(:membrane_webrtc_to_hls_demo, :hls_output_mount_path),
      target_window_duration: :infinity
    }

    :ok = Engine.add_endpoint(pid, endpoint)

    {:ok,
     %{
       rtc_engine: pid,
       channel_pid: channel_pid,
       peer: nil,
       network_options: network_options,
       trace_ctx: trace_ctx
     }}
  end

  @impl true
  def handle_info({:playlist_playable, :audio, _playlist_idl, _peer_id}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:playlist_playable, :video, playlist_idl, _peer_id}, state) do
    send(state.channel_pid, {:playlist_playable, playlist_idl})
    {:noreply, state}
  end

  @impl true
  def handle_info({:add_peer_channel, peer_channel_pid, _peer_id}, state) do
    state = %{state | channel_pid: peer_channel_pid}
    Process.monitor(peer_channel_pid)
    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.MediaEvent{to: _, data: data}, state) do
    send(state.channel_pid, {:media_event, data})
    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.NewPeer{rtc_engine: rtc_engine, peer: peer}, state) do
    Membrane.Logger.info("New peer: #{inspect(peer)}. Accepting.")
    peer_channel_pid = state.channel_pid
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
      owner: self(),
      integrated_turn_options: state.network_options[:integrated_turn_options],
      integrated_turn_domain: state.network_options[:integrated_turn_domain],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer.id],
      trace_context: state.trace_ctx,
      webrtc_extensions: [Mid, Rid],
      filter_codecs: fn {rtp, fmtp} ->
        case rtp.encoding do
          "opus" -> true
          "H264" -> fmtp.profile_level_id === 0x42E01F
          _unsupported_codec -> false
        end
      end
    }

    Engine.accept_peer(rtc_engine, peer.id)
    :ok = Engine.add_endpoint(rtc_engine, endpoint, peer_id: peer.id, node: peer_node)

    state = %{state | peer: peer}

    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.PeerLeft{peer: peer}, state) do
    Membrane.Logger.info("Peer #{inspect(peer.id)} left RTC Engine")
    {:noreply, state}
  end

  @impl true
  def handle_info(%Message.EndpointCrashed{endpoint_id: endpoint_id}, state) do
    Membrane.Logger.error("Endpoint #{inspect(endpoint_id)} has crashed!")

    error_message = "WebRTC endpoint has crashed, please refresh the page to reconnect"
    data = MediaEvent.create_error_event(error_message)
    send(state.peer_channel, {:media_event, data})

    {:noreply, state}
  end

  # media_event coming from client
  @impl true
  def handle_info({:media_event, _from, _event} = msg, state) do
    Engine.receive_media_event(state.rtc_engine, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:cleanup, _clean_function, stream_id}, state) do
    StorageCleanup.remove_directory(stream_id)
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    if pid == state.rtc_engine do
      {:stop, :normal, state}
    else
      Engine.remove_peer(state.rtc_engine, state.peer.id)
      state = %{state | peer: nil, channel_pid: nil}
      {:noreply, state}
    end
  end

  defp create_context(name) do
    metadata = [
      {:"library.language", :elixir},
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
