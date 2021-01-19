defmodule WebRTCEndpoint do
  use Membrane.Bin
  require Membrane.Logger

  def_input_pad :input,
    demand_unit: :buffers,
    caps: :any,
    availability: :on_request,
    options: [encoding: []]

  def_output_pad :output, demand_unit: :buffers, caps: :any, availability: :on_request

  alias EchoDemo.Echo.SDPUtils
  alias EchoDemo.Echo.WS

  @audio_ssrc 4_112_531_724
  @video_ssrc 3_766_692_804

  @impl true
  def handle_init(_opts) do
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
      ice_funnel: Membrane.Funnel
    }

    ice_output_pad = Pad.ref(:output, 1)
    ice_input_pad = Pad.ref(:input, 1)

    links = [
      link(:ice)
      |> via_out(ice_output_pad)
      |> via_in(:rtp_input)
      |> to(:rtp),
      link(:ice_funnel)
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
      :ssrcs => [{4_112_531_724, 3_766_692_804}, {4_112_531_725, 3_766_692_805}]
    }

    {{:ok, spec: spec}, state}
  end

  defp hex_dump(digest_str) do
    digest_str
    |> :binary.bin_to_list()
    |> Enum.map_join(":", &Base.encode16(<<&1>>))
  end

  @impl true
  def handle_pad_added(Pad.ref(:input, _ref) = pad, ctx, state) do
    %{encoding: encoding} = ctx.options

    {_children, _input_link, ssrc} =
      case encoding do
        :H264 ->
          children = %{h264_parser: %Membrane.H264.FFmpeg.Parser{alignment: :nal}}
          link = link_bin_input(pad) |> to(:h264_parser)
          {children, link, @video_ssrc}

        :OPUS ->
          {%{}, link_bin_input(pad), @audio_ssrc}
      end

    children = %{}
    input_link = link_bin_input(pad)

    spec = %ParentSpec{
      children: children,
      links: [
        input_link
        |> via_in(Pad.ref(:input, ssrc))
        |> to(:rtp)
        |> via_out(Pad.ref(:rtp_output, ssrc), options: [encoding: encoding])
        |> to(:ice_funnel)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:output, {encoding, ssrc}) = pad, _ctx, state) do
    spec =
      case encoding do
        :H264 ->
          %ParentSpec{
            children: %{{:h264_parser, ssrc} => %Membrane.H264.FFmpeg.Parser{alignment: :nal}},
            links: [
              link(:rtp)
              |> via_out(Pad.ref(:output, ssrc), options: [encoding: encoding])
              |> to({:h264_parser, ssrc})
              |> to_bin_output(pad)
            ]
          }

        :OPUS ->
          %ParentSpec{
            links: [
              link(:rtp)
              |> via_out(Pad.ref(:output, ssrc), options: [encoding: encoding])
              |> to_bin_output(pad)
            ]
          }
      end

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, pt}, _from, _ctx, state) do
    %{encoding_name: encoding} = Membrane.RTP.PayloadFormat.get_payload_type_mapping(pt)
    {{:ok, notify: {:new_stream, encoding, {encoding, ssrc}}}, state}
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
    actions = notify_offer(state) ++ notify_buffered_candidates(state)
    {{:ok, actions}, state}
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
    {{:ok, notify: {:signal, WS.candidate_msg(cand, 0, 0)}}, state}
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

  defp notify_offer(state) do
    offer = SDPUtils.create_offer(state[:ice_ufrag], state[:ice_pwd], state[:fingerprint])
    [notify: {:signal, WS.offer_msg(offer)}]
  end

  defp notify_buffered_candidates(state) do
    state[:candidates]
    |> Enum.flat_map(fn cand ->
      [notify: {:signal, WS.candidate_msg(cand, 0, 0)}]
    end)
  end

  defp parse_answer(sdp, _state) do
    {:ok, sdp} = sdp |> ExSDP.parse()
    remote_credentials = SDPUtils.get_remote_credentials(sdp)
    [forward: {:ice, {:set_remote_credentials, remote_credentials}}]
  end
end
