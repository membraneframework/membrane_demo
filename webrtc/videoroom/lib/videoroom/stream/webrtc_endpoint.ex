defmodule VideoRoom.Stream.WebRTCEndpoint do
  use Membrane.Bin
  require Membrane.Logger

  def_input_pad :input,
    demand_unit: :buffers,
    caps: :any,
    availability: :on_request,
    options: [encoding: []]

  def_output_pad :output, demand_unit: :buffers, caps: :any, availability: :on_request

  alias VideoRoom.Stream.SDPUtils

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
      candidates: [],
      offer_sent: false,
      dtls_fingerprint: nil,
      ssrcs: %{OPUS: [110, 120, 130], H264: [210, 220, 230]}
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
    {ssrc, state} = get_and_update_in(state, [:ssrcs, encoding], fn [h | t] -> {h, t} end)

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
    {:ok, %{state | dtls_fingerprint: hex_dump(fingerprint)}}
  end

  @impl true
  def handle_notification({:local_credentials, credentials}, _from, _ctx, state) do
    [ice_ufrag, ice_pwd] = String.split(credentials, " ")

    actions =
      notify_offer(ice_ufrag, ice_pwd, state.dtls_fingerprint) ++
        notify_candidates(state.candidates)

    {{:ok, actions}, %{state | candidates: [], offer_sent: true}}
  end

  @impl true
  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{offer_sent: false} = state) do
    state = Map.update!(state, :candidates, &[cand | &1])
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{offer_sent: true} = state) do
    {{:ok, notify_candidates([cand])}, state}
  end

  @impl true
  def handle_notification(_notification, _from, _ctx, state) do
    {:ok, state}
  end

  @impl true
  def handle_other({:signal, {:sdp_answer, sdp}}, _ctx, state) do
    {:ok, sdp} = sdp |> ExSDP.parse()
    remote_credentials = SDPUtils.get_remote_credentials(sdp)
    {{:ok, forward: {:ice, {:set_remote_credentials, remote_credentials}}}, state}
  end

  @impl true
  def handle_other({:signal, {:candidate, candidate}}, _ctx, state) do
    {{:ok, forward: {:ice, {:set_remote_candidate, "a=" <> candidate, 1}}}, state}
  end

  defp notify_offer(ice_ufrag, ice_pwd, dtls_fingerprint) do
    offer = SDPUtils.create_offer(ice_ufrag, ice_pwd, dtls_fingerprint)
    [notify: {:signal, {:sdp_offer, offer}}]
  end

  defp notify_candidates(candidates) do
    Enum.flat_map(candidates, fn cand ->
      [notify: {:signal, {:candidate, cand, 0, "audio1"}}]
    end)
  end
end
