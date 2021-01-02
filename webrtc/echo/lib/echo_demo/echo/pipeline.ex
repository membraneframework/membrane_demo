defmodule EchoDemo.Echo.Pipeline do
  use Membrane.Pipeline

  require Membrane.Logger

  alias EchoDemo.Echo.SDPUtils
  alias EchoDemo.Echo.WS

  @audio_ssrc 4_112_531_724
  @video_ssrc 3_766_692_804

  @impl true
  def handle_init(opts) do
    children = %{
      ice: %Membrane.ICE.Bin{
        stun_servers: ["64.233.161.127:19302"],
        controlling_mode: true,
        handshake_module: Membrane.DTLS.Handshake,
        handshake_opts: [client_mode: false, dtls_srtp: true]
      },
      rtp: %Membrane.RTP.SessionBin{
        secure?: true
      },
      funnel: Membrane.Funnel
    }

    ice_output_pad = Pad.ref(:output, 1)
    ice_input_pad = Pad.ref(:input, 1)

    links = [
      link(:ice)
      |> via_out(ice_output_pad)
      |> via_in(:rtp_input)
      |> to(:rtp),
      link(:funnel)
      |> via_out(:output)
      |> via_in(ice_input_pad)
      |> to(:ice)
    ]

    spec = %ParentSpec{
      children: children,
      links: links
    }

    state = %{
      :candidates => [],
      :offer_sent => false,
      :ws_pid => opts[:ws_pid]
    }

    {{:ok, spec: spec}, state}
  end

  defp hex_dump(digest_str) do
    digest_str
    |> :binary.bin_to_list()
    |> Enum.map_join(":", &Base.encode16(<<&1>>))
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
        |> to(:funnel)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 108}, _from, _ctx, state) do
    spec = %ParentSpec{
      children: %{
        realtimer_video: Membrane.Realtimer,
        video_parser: %Membrane.H264.FFmpeg.Parser{framerate: {30, 1}, alignment: :nal}
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: :H264, clock_rate: 90000])
        |> to(:realtimer_video)
        |> to(:video_parser)
        |> via_in(Pad.ref(:input, @video_ssrc))
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, @video_ssrc),
          options: [payload_type: 108, encoding: :H264, clock_rate: 90000]
        )
        |> to(:funnel)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:handshake_init_data, _component_id, fingerprint}, _from, _ctx, state) do
    state = Map.put(state, :fingerprint, hex_dump(fingerprint))
    {:ok, state}
  end

  @impl true
  def handle_notification({:local_credentials, credentials} = msg, _from, _ctx, state) do
    Membrane.Logger.info("#{inspect(msg)}")
    [ice_ufrag, ice_pwd] = String.split(credentials, " ")
    state = Map.put(state, :ice_ufrag, ice_ufrag)
    state = Map.put(state, :ice_pwd, ice_pwd)
    state = Map.put(state, :offer_sent, true)
    send_offer(state)
    send_buffered_candidates(state)
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{offer_sent: false} = state) do
    candidates = Map.get(state, :candidates, [])
    candidates = [cand] ++ candidates
    state = Map.put(state, :candidates, candidates)
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{offer_sent: true} = state) do
    WS.send_candidate(state[:ws_pid], cand, 0, 0)
    {:ok, state}
  end

  @impl true
  def handle_notification(_notification, _from, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_other({:event, msg}, _ctx, state) do
    case msg["event"] do
      "answer" ->
        actions = parse_answer(msg["data"]["sdp"], state)
        {{:ok, actions}, state}

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

  defp send_offer(state) do
    offer = SDPUtils.create_offer(state[:ice_ufrag], state[:ice_pwd], state[:fingerprint])
    WS.send_offer(state[:ws_pid], offer)
  end

  defp send_buffered_candidates(state) do
    state[:candidates]
    |> Enum.each(fn cand ->
      WS.send_candidate(state[:ws_pid], cand, 0, 0)
    end)
  end

  defp parse_answer(sdp, _state) do
    {:ok, sdp} = sdp |> ExSDP.parse()
    remote_credentials = SDPUtils.get_remote_credentials(sdp)
    [forward: {:ice, {:set_remote_credentials, remote_credentials}}]
  end
end
