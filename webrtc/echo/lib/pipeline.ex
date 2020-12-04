defmodule Membrane.Echo.Pipeline do
  use Membrane.Pipeline

  require Membrane.Logger

  alias Membrane.File
  alias Membrane.Protocol.SDP

  @audio_ssrc 4_112_531_724
  @video_ssrc 3_766_692_804

  @impl true
  def handle_init(_) do
    {:ok, crypto_profile} = ExLibSRTP.Policy.crypto_profile_from_dtls_srtp_protection_profile(1)

    policies = [
      %ExLibSRTP.Policy{
        ssrc: :any_inbound,
        key:
          <<164, 49, 246, 47, 127, 176, 148, 221, 181, 160, 66, 140, 92, 189, 205, 34, 45, 64,
            149, 207, 181, 172, 190, 157, 174, 234, 43, 83, 188, 80>>,
        rtp: crypto_profile,
        rtcp: crypto_profile
      }
    ]

    children = %{
      ice: %Membrane.ICE.Bin{
        stun_servers: ["64.233.161.127:19302"],
        controlling_mode: false,
        handshake_module: Membrane.DTLS.Handshake,
        handshake_opts: [client_mode: true, dtls_srtp: true]
      },
      rtp: %Membrane.RTP.SessionBin{
        secure?: true,
        srtp_policies: policies,
        custom_depayloaders: %{:OPUS => Membrane.RTP.Opus.Depayloader}
      }
    }

    pad = Pad.ref(:output, 1)

    links = [
      link(:ice)
      |> via_out(pad)
      |> via_in(:rtp_input)
      |> to(:rtp)
    ]

    spec = %ParentSpec{
      children: children,
      links: links
    }

    {{:ok, spec: spec}, %{}}
  end

  defp hex_dump(digest_str) do
    digest_str
    |> :binary.bin_to_list()
    |> Enum.map_join(":", &Base.encode16(<<&1>>))
  end

  def handle_prepared_to_playing(_ctx, state) do
    {:ok, ws_pid} = WS.start_link("wss://localhost:8443/webrtc/room", %{parent: self()})
    {:ok, Map.put(state, :ws_pid, ws_pid)}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 111}, _from, _ctx, state) do
    spec = %ParentSpec{
      children: %{
        realtimer_audio: Membrane.Realtimer
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: :OPUS, clock_rate: 48000])
        |> to(:realtimer_audio)
        |> via_in(Pad.ref(:input, @audio_ssrc))
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, @audio_ssrc),
             options: [payload_type: 111, encoding: :OPUS, clock_rate: 48000]
           )
        |> via_in(:input, options: [component_id: 1])
        |> to(:ice)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 108}, _from, _ctx, state) do
    spec = %ParentSpec{
      children: %{
        realtimer_video: Membrane.Realtimer
        # video_parser: %Membrane.H264.FFmpeg.Parser{framerate: {30, 1}},
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: :H264, clock_rate: 90000])
        |> to(:realtimer_video)
        |> via_in(Pad.ref(:input, @video_ssrc))
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, @video_ssrc),
          options: [payload_type: 108, encoding: :H264, clock_rate: 90000]
        )
        |> via_in(:input, options: [component_id: 1])
        |> to(:ice)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  def handle_notification(
        {:component_ready, component_id, handshake_data} = msg,
        _from,
        _ctx,
        state
      ) do
    Membrane.Logger.info("#{inspect(msg)}")
    new_state = Map.put(state, :ready_component, component_id)
    new_state = Map.put(new_state, :handshake_data, handshake_data)
    {:ok, new_state}
  end

  @impl true
  def handle_notification({:handshake_init_data, _component_id, fingerprint}, _from, _ctx, state) do
    new_state = Map.put(state, :fingerprint, hex_dump(fingerprint))
    {:ok, new_state}
  end

  def handle_notification({:local_credentials, credentials} = msg, _from, _ctx, state) do
    Membrane.Logger.info("#{inspect(msg)}")
    [ice_ufrag, ice_pwd] = String.split(credentials, " ")
    new_state = Map.put(state, :ice_ufrag, ice_ufrag)
    new_state = Map.put(new_state, :ice_pwd, ice_pwd)
    {:ok, new_state}
  end

  def handle_notification(notification, from, _ctx, state) do
    Membrane.Logger.warn(
      "unhandled notification: #{inspect(notification)}} from: #{inspect(from)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_other({:set_remote_credentials, remote_credentials}, _ctx, state) do
    {{:ok, forward: {:ice, {:set_remote_credentials, remote_credentials}}}, state}
  end

  @impl true
  def handle_other({:set_remote_candidate, candidate}, _ctx, state) do
    {{:ok, forward: {:ice, {:set_remote_candidate, candidate, 1}}}, state}
  end

  @impl true
  def handle_other({:event, msg}, _ctx, state) do
    IO.inspect(msg, printable_limit: :infinity, limit: :infinity)
    msg = Poison.decode!(msg)

    case msg["event"] do
      "offer" ->
        {:ok, offer} = Membrane.Protocol.SDP.parse(msg["data"]["sdp"])
        fmt_mappings = get_fmt_mappings(offer)
        state = Map.put(state, :offer, offer)
        state = Map.put(state, :from, msg["to"])
        state = Map.put(state, :to, msg["from"])
        state = Map.put(state, :fmt_mappings, fmt_mappings)
        remote_credentials = get_remote_credentials(offer)
        send_answer(offer, state)
        {{:ok, forward: {:ice, {:set_remote_credentials, remote_credentials}}}, state}

      "candidate" ->
        candidate = msg["data"]["candidate"]
        {{:ok, forward: {:ice, {:set_remote_candidate, "a=" <> candidate, 1}}}, state}

      _ ->
        {:ok, state}
    end
  end

  @impl true
  def handle_other(other, _ctx, state) do
    {{:ok, forward: {:ice, other}}, state}
  end

  def get_pt(list) do
    list |> Enum.map(fn {pt, _en} -> pt end)
  end

  def send_answer(offer, state) do
    answer =
      prepare_answer(offer, state[:ice_ufrag], state[:ice_pwd], state[:fingerprint])
      |> SDP.serialize()

    WS.send_answer(state[:ws_pid], answer, state[:from], state[:to])
  end

  def get_remote_credentials(offer) do
    attributes = List.first(offer.media).attributes

    attributes
    |> Enum.reject(fn %SDP.Attribute{key: key} -> key not in ["ice-ufrag", "ice-pwd"] end)
    |> Enum.map_join(" ", fn %SDP.Attribute{value: value} -> value end)
  end

  def get_fmt_mappings(offer) do
    res =
      offer.media
      |> Enum.map(fn m ->
        l =
          m.attributes
          |> Enum.reject(fn %SDP.Attribute{key: key} -> key != :rtpmap end)
          |> Enum.map(fn a -> {a.value.payload_type, a.value.encoding} end)

        {m.type, l}
      end)

    IO.inspect(res, label: "result")
    res
  end

  def prepare_answer(_offer, ice_ufrag, ice_pwd, fingerprint) do
    {:ok, offer} = get_offer()

    media =
      offer.media
      |> Enum.map(fn m ->
        new_attr =
          m.attributes
          |> Enum.map(fn %SDP.Attribute{key: key} = a ->
            case key do
              "ice-ufrag" -> %SDP.Attribute{a | value: ice_ufrag}
              "ice-pwd" -> %SDP.Attribute{a | value: ice_pwd}
              "fingerprint" -> %SDP.Attribute{a | value: "sha-256 " <> fingerprint}
              _ -> a
            end
          end)

        %SDP.Media{m | attributes: new_attr}
      end)

    %SDP{offer | media: media}
  end

  def get_offer() do
    """
    v=0
    o=- 7263753815578774817 2 IN IP4 127.0.0.1
    s=-
    t=0 0
    a=group:BUNDLE 0 1
    a=msid-semantic: WMS 0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANS
    m=audio 9 UDP/TLS/RTP/SAVPF 111
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:active
    a=mid:0
    a=sendrecv
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANS 0c68dcf5-db98-4c3f-b0f2-ff1918ed80ba
    a=rtcp-mux
    a=rtpmap:111 opus/48000/2
    a=rtcp-fb:111 transport-cc
    a=fmtp:111 minptime=10;useinbandfec=1
    a=ssrc:4112531724 cname:HPd3XfRHXYUxzfsJ
    m=video 9 UDP/TLS/RTP/SAVPF 108
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:active
    a=mid:1
    a=sendrecv
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANS a60cccca-f708-49e7-89d0-4be0524658a5
    a=rtcp-mux
    a=rtcp-rsize
    a=rtpmap:108 H264/90000
    a=rtcp-fb:108 goog-remb
    a=rtcp-fb:108 transport-cc
    a=rtcp-fb:108 ccm fir
    a=rtcp-fb:108 nack
    a=rtcp-fb:108 nack pli
    a=fmtp:108 level-asymmetry-allowed=1;packetization-mode=0;profile-level-id=42e01f
    a=ssrc-group:FID 3766692804 1412308393
    a=ssrc:3766692804 cname:HPd3XfRHXYUxzfsJ
    a=ssrc:1412308393 cname:HPd3XfRHXYUxzfsJ
    """
    |> Membrane.Protocol.SDP.parse()
  end
end
