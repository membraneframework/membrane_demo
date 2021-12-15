defmodule WebRTCToHLS.Stream do
  @moduledoc false

  use GenServer

  require Membrane.Logger
  alias Membrane.RTC.Engine.Endpoint.{WebRTC, HLS}
  alias Membrane.RTC.Engine
  alias Membrane.WebRTC.Extension.{Mid, Rid}
  alias WebRTCToHLS.StorageCleanup

  def start(channel_pid) do
    GenServer.start(__MODULE__, [channel_pid])
  end

  @impl true
  def init([channel_pid]) do
    Membrane.Logger.info(
      "Spawning stream process for channel: #{inspect(self())} for channel #{inspect(channel_pid)}"
    )

    Process.monitor(channel_pid)

    rtc_options = [
      id: UUID.uuid4()
    ]

    {:ok, pid} = Membrane.RTC.Engine.start(rtc_options, [])

    Engine.register(pid, self())

    StorageCleanup.clean_unused_directories()

    endpoint = %HLS{
      owner: self(),
      output_directory:
        Application.fetch_env!(:membrane_webrtc_to_hls_demo, :hls_output_mount_path)
    }

    :ok = Engine.add_endpoint(pid, endpoint, endpoint_id: "hls", node: node())

    {:ok, %{rtc_engine: pid, channel_pid: channel_pid}}
  end

  @impl true
  def handle_info({:playlist_playable, :audio, _playlist_idl}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:playlist_playable, :video, playlist_idl}, state) do
    send(state.channel_pid, {:playlist_playable, playlist_idl})
    {:noreply, state}
  end

  @impl true
  def handle_info({_rtc_engine, {:rtc_media_event, :broadcast, event}}, state) do
    # just a single channel broadcast?
    send(state.channel_pid, {:media_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_info({_rtc_engine, {:rtc_media_event, _to, event}}, state) do
    send(state.channel_pid, {:media_event, event})
    {:noreply, state}
  end

  @impl true
  def handle_info({rtc_engine, {:new_peer, peer_id, _metadata}}, state) do
    network_options = [
      stun_servers: [
        %{server_addr: "stun.l.google.com", server_port: 19_302}
      ],
      turn_servers: [],
      dtls_pkey: Application.get_env(:membrane_videoroom_demo, :dtls_pkey),
      dtls_cert: Application.get_env(:membrane_videoroom_demo, :dtls_cert)
    ]

    handshake_opts =
      if network_options[:dtls_pkey] &&
           network_options[:dtls_cert] do
        [
          client_mode: false,
          dtls_srtp: true,
          pkey: network_options[:dtls_pkey],
          cert: network_options[:dtls_cert]
        ]
      else
        [
          client_mode: false,
          dtls_srtp: true
        ]
      end

    endpoint = %WebRTC{
      ice_name: peer_id,
      extensions: %{},
      owner: self(),
      stun_servers: network_options[:stun_servers] || [],
      turn_servers: network_options[:turn_servers] || [],
      handshake_opts: handshake_opts,
      log_metadata: [peer_id: peer_id],
      webrtc_extensions: [Mid, Rid],
      filter_codecs: fn {rtp, fmtp} ->
        case rtp.encoding do
          "opus" -> true
          "H264" -> fmtp.profile_level_id === 0x42E01F
          _unsupported_codec -> false
        end
      end
    }

    Engine.accept_peer(rtc_engine, peer_id)

    :ok = Engine.add_endpoint(rtc_engine, endpoint, peer_id: peer_id, node: node())

    {:noreply, state}
  end

  @impl true
  def handle_info({_rtc_engine, {:peer_left, _peer_id}}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:media_event, _from, _event} = msg, state) do
    send(state.rtc_engine, msg)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, %{channel_pid: pid} = state) do
    Membrane.Pipeline.stop_and_terminate(state.rtc_engine)
    {:stop, :normal, state}
  end
end
