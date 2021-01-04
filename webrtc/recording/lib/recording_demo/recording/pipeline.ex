defmodule RecordingDemo.Recording.Pipeline do
  use Membrane.Pipeline

  alias RecordingDemo.Recording.{SDPUtils, TimeLimiter, WS}
  alias Membrane.Element.IVF

  require Membrane.Logger

  @impl true
  def handle_init(opts) do
    Membrane.Logger.info("Starting recording pipeline, room: #{opts.room}")

    children = %{
      ice: %Membrane.ICE.Bin{
        stun_servers: ["64.233.161.127:19302"],
        controlling_mode: true,
        handshake_module: Membrane.DTLS.Handshake,
        handshake_opts: [client_mode: false, dtls_srtp: true]
      },
      rtp: %Membrane.RTP.SessionBin{secure?: true}
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
      room: opts.room,
      output_name:
        "#{Membrane.Time.pretty_now() |> String.replace("\:", "-")}_#{:erlang.phash2(make_ref())}.ivf",
      candidates: [],
      ws: nil,
      peer_id: nil,
      authenticated: false,
      ice: nil
    }

    play(self())
    {{:ok, log_metadata: [room: opts.room], spec: spec}, state}
  end

  defp hex_dump(digest_str) do
    digest_str
    |> :binary.bin_to_list()
    |> Enum.map_join(":", &Base.encode16(<<&1>>))
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, 98}, _from, _ctx, state) do
    Membrane.Logger.info("Received RTP stream")
    WS.send_recording(state.ws, state.peer_id, "all")

    spec = %ParentSpec{
      children: %{
        video_file_sink: %Membrane.File.Sink{
          location: "#{:code.priv_dir(:recording_demo)}/static/output/#{state.output_name}"
        },
        time_limiter: %TimeLimiter{time_limit: 10 |> Membrane.Time.seconds()},
        ivf_writter:
           %IVF{width: 400, height: 300, scale: 1, rate: 30}
      },
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: :VP9, clock_rate: 90_000])
        |> to(:time_limiter)
        |> to(:ivf_writter)
        |> to(:video_file_sink)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, pt}, :rtp, _ctx, _state) do
    raise "Unsupported RTP stream, ssrc: #{ssrc}, payload type: #{pt}"
  end

  @impl true
  def handle_notification({:handshake_init_data, _component_id, fingerprint}, :ice, _ctx, state) do
    new_state = Map.put(state, :fingerprint, hex_dump(fingerprint))
    {:ok, new_state}
  end

  @impl true
  def handle_notification({:local_credentials, credentials}, :ice, _ctx, state) do
    [ufrag, pwd] = String.split(credentials, " ")
    ice = %{ufrag: ufrag, pwd: pwd}
    {:ok, ws} = WS.start_link("wss://127.0.0.1:8443/membrane/#{state.room}", %{parent: self()})
    {:ok, %{state | ice: ice, ws: ws}}
  end

  @impl true
  def handle_notification({:new_candidate_full, candidate}, :ice, _ctx, state) do
    state = Map.update!(state, :candidates, &[candidate | &1]) |> maybe_send_candidates()
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_remote_candidate_full, _candidate}, :ice, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_notification(:candidate_gathering_done, :ice, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_notification(notification, _from, _ctx, state) do
    Membrane.Logger.warn("Unhandled notification: #{inspect(notification)}")
    {:ok, state}
  end

  @impl true
  def handle_element_end_of_stream({:video_file_sink, :input}, _ctx, state) do
    Membrane.Logger.info("Recording finished")
    WS.send_recorded(state.ws, state.output_name, state.peer_id, "all")
    stop_and_terminate(self())
    {:ok, state}
  end

  @impl true
  def handle_element_end_of_stream(_endpoint, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_other({:event, msg}, _ctx, state) do
    case msg["event"] do
      "authenticated" ->
        state = %{state | authenticated: true, peer_id: msg["from"]}
        send_offer(state)
        state = maybe_send_candidates(state)
        {:ok, state}

      "answer" ->
        actions = parse_answer(msg["data"]["sdp"])
        {{:ok, actions}, state}

      "candidate" ->
        candidate = msg["data"]["candidate"]
        {{:ok, forward: {:ice, {:set_remote_candidate, "a=" <> candidate, 1}}}, state}

      _ ->
        {:ok, state}
    end
  end

  defp send_offer(state) do
    offer = SDPUtils.create_offer(state.ice.ufrag, state.ice.pwd, state[:fingerprint])
    WS.send_offer(state.ws, offer, state.peer_id, "all")
  end

  defp maybe_send_candidates(%{authenticated: true} = state) do
    Enum.each(state.candidates, &WS.send_candidate(state.ws, &1, 0, 1, "all"))
    %{state | candidates: []}
  end

  defp maybe_send_candidates(state) do
    state
  end

  defp parse_answer(sdp) do
    {:ok, sdp} = sdp |> ExSDP.parse()
    remote_credentials = SDPUtils.get_remote_credentials(sdp)
    [forward: {:ice, {:set_remote_credentials, remote_credentials}}]
  end
end
