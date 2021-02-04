defmodule VideoRoom.Stream.WebRTCEndpoint do
  use Membrane.Bin
  require Membrane.Logger
  alias ExSDP.Attribute.RTPMapping

  def_input_pad :input,
    demand_unit: :buffers,
    caps: :any,
    availability: :on_request,
    options: [encoding: []]

  def_output_pad :output, demand_unit: :buffers, caps: :any, availability: :on_request

  alias Membrane.WebRTC.SDP
  alias ExSDP.Media

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

    rtp_input_ref = make_ref()

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:rtcp_output, rtp_input_ref))
      |> to(:ice_funnel),
      link(:ice)
      |> via_out(ice_output_pad)
      |> via_in(Pad.ref(:rtp_input, rtp_input_ref))
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
      ssrcs: %{OPUS: [110, 120, 130], VP9: [210, 220, 230]}
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

    spec =
      case encoding do
        :H264 ->
          %ParentSpec{
            children: %{{:h264_parser, ssrc} => %Membrane.H264.FFmpeg.Parser{alignment: :nal}},
            links: [
              link_bin_input(pad)
              |> to({:h264_parser, ssrc})
              |> via_in(Pad.ref(:input, ssrc))
              |> to(:rtp)
              |> via_out(Pad.ref(:rtp_output, ssrc), options: [encoding: encoding])
              |> to(:ice_funnel)
            ]
          }

        :OPUS ->
          %ParentSpec{
            links: [
              link_bin_input(pad)
              |> via_in(Pad.ref(:input, ssrc))
              |> to(:rtp)
              |> via_out(Pad.ref(:rtp_output, ssrc), options: [encoding: encoding])
              |> to(:ice_funnel)
            ]
          }

        :VP9 ->
          %ParentSpec{
            links: [
              link_bin_input(pad)
              |> via_in(Pad.ref(:input, ssrc))
              |> to(:rtp)
              |> via_out(Pad.ref(:rtp_output, ssrc), options: [encoding: encoding])
              |> to(:ice_funnel)
            ]
          }
      end

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:output, {encoding, ssrc}) = pad, _ctx, state) do
    spec = %ParentSpec{
      links: [
        link(:rtp)
        |> via_out(Pad.ref(:output, ssrc), options: [encoding: encoding])
        |> to_bin_output(pad)
      ]
    }

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_notification({:new_rtp_stream, ssrc, pt}, _from, _ctx, state) do
    %{encoding_name: encoding} = Membrane.RTP.PayloadFormat.get_payload_type_mapping(pt)
    {{:ok, notify: {:new_stream, encoding, {encoding, ssrc}}}, state}
  end

  @impl true
  def handle_notification({:handshake_init_data, _component_id, fingerprint}, _from, _ctx, state) do
    {:ok, %{state | dtls_fingerprint: {:sha256, hex_dump(fingerprint)}}}
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
    remote_credentials = get_remote_credentials(sdp)
    {{:ok, forward: {:ice, {:set_remote_credentials, remote_credentials}}}, state}
  end

  @impl true
  def handle_other({:signal, {:candidate, candidate}}, _ctx, state) do
    {{:ok, forward: {:ice, {:set_remote_candidate, "a=" <> candidate, 1}}}, state}
  end

  defp notify_offer(ice_ufrag, ice_pwd, dtls_fingerprint) do
    ssrcs = %{audio: [110, 120, 130], video: [210, 220, 230]}

    opts = %SDP.Opts{
      peers: 3,
      ssrcs: ssrcs,
      video_codecs: [{:VP9, %RTPMapping{payload_type: 98, encoding: "VP9", clock_rate: 90_000}}]
    }

    offer = SDP.create_offer(ice_ufrag, ice_pwd, dtls_fingerprint, opts)
    [notify: {:signal, {:sdp_offer, to_string(offer)}}]
  end

  defp notify_candidates(candidates) do
    Enum.flat_map(candidates, fn cand ->
      [notify: {:signal, {:candidate, cand, 0, "0"}}]
    end)
  end

  defp get_remote_credentials(sdp) do
    media = List.first(sdp.media)
    {_key, ice_ufrag} = Media.get_attribute(media, :ice_ufrag)
    {_key, ice_pwd} = Media.get_attribute(media, :ice_pwd)
    ice_ufrag <> " " <> ice_pwd
  end
end
