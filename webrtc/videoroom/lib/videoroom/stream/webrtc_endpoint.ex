defmodule VideoRoom.Stream.WebRTCEndpoint do
  use Membrane.Bin

  alias Membrane.WebRTC.Track

  require Membrane.Logger

  def_options inbound_tracks: [], outbound_tracks: []

  def_input_pad :input,
    demand_unit: :buffers,
    caps: :any,
    availability: :on_request,
    options: [encoding: []]

  def_output_pad :output, demand_unit: :buffers, caps: :any, availability: :on_request

  alias Membrane.WebRTC.SDP
  alias ExSDP.Media

  @impl true
  def handle_init(opts) do
    children = %{
      ice: %Membrane.ICE.Bin{
        stun_servers: ["64.233.161.127:19302"],
        controlling_mode: true,
        handshake_module: Membrane.DTLS.Handshake,
        handshake_opts: [client_mode: false, dtls_srtp: true]
      },
      rtp: %Membrane.RTP.SessionBin{secure?: true},
      ice_funnel: Membrane.Funnel
    }

    rtp_input_ref = make_ref()

    links = [
      link(:rtp)
      |> via_out(Pad.ref(:rtcp_output, rtp_input_ref))
      |> to(:ice_funnel),
      link(:ice)
      |> via_out(Pad.ref(:output, 1))
      |> via_in(Pad.ref(:rtp_input, rtp_input_ref))
      |> to(:rtp),
      link(:ice_funnel)
      |> via_out(:output)
      |> via_in(Pad.ref(:input, 1))
      |> to(:ice)
    ]

    spec = %ParentSpec{
      children: children,
      links: links
    }

    state =
      %{
        inbound_tracks: %{},
        outbound_tracks: %{},
        candidates: [],
        offer_sent: false,
        dtls_fingerprint: nil
      }
      |> add_tracks(:inbound_tracks, opts.inbound_tracks)
      |> add_tracks(:outbound_tracks, opts.outbound_tracks)

    {{:ok, spec: spec}, state}
  end

  defp hex_dump(digest_str) do
    digest_str
    |> :binary.bin_to_list()
    |> Enum.map_join(":", &Base.encode16(<<&1>>))
  end

  @impl true
  def handle_pad_added(Pad.ref(:input, track_id) = pad, ctx, state) do
    %{encoding: encoding} = ctx.options
    %Track{ssrc: ssrc} = Map.fetch!(state.outbound_tracks, track_id)

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
      end

    {{:ok, spec: spec}, state}
  end

  @impl true
  def handle_pad_added(Pad.ref(:output, track_id) = pad, _ctx, state) do
    %Track{ssrc: ssrc, encoding: encoding} = Map.fetch!(state.inbound_tracks, track_id)

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
    type = if encoding == :OPUS, do: :audio, else: :video
    track = state.inbound_tracks |> Map.values() |> Enum.find(&(&1.type == type))
    track = %Track{track | ssrc: ssrc, encoding: encoding}
    state = put_in(state, [:inbound_tracks, track.id], track)
    {{:ok, notify: {:new_track, track.id, encoding}}, state}
  end

  @impl true
  def handle_notification({:handshake_init_data, _component_id, fingerprint}, _from, _ctx, state) do
    {:ok, %{state | dtls_fingerprint: {:sha256, hex_dump(fingerprint)}}}
  end

  @impl true
  def handle_notification({:local_credentials, credentials}, _from, _ctx, state) do
    [ice_ufrag, ice_pwd] = String.split(credentials, " ")

    offer =
      SDP.create_offer(
        inbound_tracks: Map.values(state.inbound_tracks),
        outbound_tracks: Map.values(state.outbound_tracks),
        ice_ufrag: ice_ufrag,
        ice_pwd: ice_pwd,
        fingerprint: state.dtls_fingerprint
      )

    IO.puts(offer)

    actions =
      [notify: {:signal, {:sdp_offer, to_string(offer)}}] ++
        notify_candidates(state.candidates)

    {{:ok, actions}, %{state | offer_sent: true}}
  end

  @impl true
  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{offer_sent: false} = state) do
    state = Map.update!(state, :candidates, &[cand | &1])
    {:ok, state}
  end

  @impl true
  def handle_notification({:new_candidate_full, cand}, _from, _ctx, %{offer_sent: true} = state) do
    state = Map.update!(state, :candidates, &[cand | &1])
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

  @impl true
  def handle_other({:add_tracks, tracks}, _ctx, state) do
    state = %{state | offer_sent: false} |> add_tracks(:outbound_tracks, tracks)
    {{:ok, forward: {:ice, :restart_stream}}, state}
  end

  defp add_tracks(state, direction, tracks) do
    tracks =
      case direction do
        :outbound_tracks ->
          Track.add_ssrc(
            tracks,
            Map.values(state.inbound_tracks) ++ Map.values(state.outbound_tracks)
          )

        :inbound_tracks ->
          tracks
      end

    tracks = Map.new(tracks, &{&1.id, &1})
    Map.update!(state, direction, &Map.merge(&1, tracks))
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
