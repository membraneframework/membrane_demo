defmodule Membrane.Recording.Pipeline do
  use Membrane.Pipeline

  alias Membrane.Recording.SDPUtils

  require Membrane.Logger

  @impl true
  def handle_init(_) do
    children = %{
      ice: %Membrane.ICE.Bin{
        stun_servers: ["64.233.161.127:19302"],
        controlling_mode: true,
        handshake_module: Membrane.DTLS.Handshake,
        handshake_opts: [client_mode: false, dtls_srtp: true]
      },
      rtp: %Membrane.RTP.SessionBin{
        secure?: true,
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

    state = %{
      :from => nil,
      :to => nil,
      :candidates => [],
      :authenticated => false
    }

    {{:ok, spec: spec}, state}
  end

  defp hex_dump(digest_str) do
    digest_str
    |> :binary.bin_to_list()
    |> Enum.map_join(":", &Base.encode16(<<&1>>))
  end

  def handle_prepared_to_playing(_ctx, state) do
    {:ok, ws_pid} = WS.start_link("wss://127.0.0.1:8443/webrtc/room", %{parent: self()})
    {:ok, Map.put(state, :ws_pid, ws_pid)}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 111}, _from, _ctx, state) do
    spec = %ParentSpec{
      children: %{
        audio_file_sink: %Membrane.File.Sink{location: "./audio_recv"}
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: :OPUS, clock_rate: 48000])
        |> to(:audio_file_sink)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 108}, _from, _ctx, state) do
    spec = %ParentSpec{
      children: %{
        video_file_sink: %Membrane.File.Sink{location: "./video_recv"}
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: :H264, clock_rate: 90000])
        |> to(:video_file_sink)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:handshake_init_data, _component_id, fingerprint}, _from, _ctx, state) do
    new_state = Map.put(state, :fingerprint, hex_dump(fingerprint))
    {:ok, new_state}
  end

  def handle_notification({:local_credentials, credentials}, _from, _ctx, state) do
    [ice_ufrag, ice_pwd] = String.split(credentials, " ")
    new_state = Map.put(state, :ice_ufrag, ice_ufrag)
    new_state = Map.put(new_state, :ice_pwd, ice_pwd)
    {:ok, new_state}
  end

  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{authenticated: false} = state) do
    candidates = Map.get(state, :candidates, [])
    # remove `a=` from the beginning ("a=candidate ..." -> "candidate ...")
    candidates = [String.slice(cand, 2..-1)] ++ candidates
    state = Map.put(state, :candidates, candidates)
    {:ok, state}
  end

  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{authenticated: true} = state) do
    WS.send_candidate(state[:ws_pid], cand, 0, 0, "all")
    {:ok, state}
  end

  def handle_notification(_notification, _from, _ctx, state) do
    Membrane.Logger.warn("unhandled notification")
    {:ok, state}
  end

  @impl true
  def handle_other({:event, msg}, _ctx, state) do
    msg = Poison.decode!(msg)

    case msg["event"] do
      "authenticated" ->
        state = Map.put(state, :to, msg["from"])
        send_offer(state)
        send_buffered_candidates(state)
        state = Map.put(state, :authenticated, true)
        {:ok, state}

      "answer" ->
        actions = parse_answer(msg["data"]["sdp"], state)
        {{:ok, actions}, state}

      "offer" ->
        {:ok, offer} = ExSDP.parse(msg["data"]["sdp"])
        state = Map.put(state, :offer, offer)
        state = Map.put(state, :from, msg["to"])
        state = Map.put(state, :to, msg["from"])
        remote_credentials = SDPUtils.get_remote_credentials(offer)
        send_answer(state)
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

  def send_answer(state) do
    answer = SDPUtils.create_answer(state[:ice_ufrag], state[:ice_pwd], state[:fingerprint])
    WS.send_answer(state[:ws_pid], answer, state[:from], state[:to])
  end

  def send_offer(state) do
    offer = SDPUtils.create_offer(state[:ice_ufrag], state[:ice_pwd], state[:fingerprint])
    WS.send_offer(state[:ws_pid], offer, state[:from], "all")
  end

  def send_buffered_candidates(state) do
    state[:candidates]
    |> Enum.each(fn cand ->
      WS.send_candidate(state[:ws_pid], cand, 0, 0, "all")
    end)
  end

  def parse_answer(sdp, _state) do
    {:ok, sdp} = sdp |> ExSDP.parse()
    remote_credentials = SDPUtils.get_remote_credentials(sdp)
    [forward: {:ice, {:set_remote_credentials, remote_credentials}}]
  end
end
