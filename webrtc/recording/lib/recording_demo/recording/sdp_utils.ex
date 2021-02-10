defmodule RecordingDemo.Recording.SDPUtils do
  alias Membrane.WebRTC.SDP
  alias ExSDP.Media
  alias ExSDP.Attribute.RTPMapping

  def get_remote_credentials(sdp) do
    media = List.first(sdp.media)
    {_key, ice_ufrag} = Media.get_attribute(media, :ice_ufrag)
    {_key, ice_pwd} = Media.get_attribute(media, :ice_pwd)
    ice_ufrag <> " " <> ice_pwd
  end

  def create_offer(ice_ufrag, ice_pwd, dtls_fingerprint) do
    ssrcs = %{
      video: [210]
    }

    opts = %SDP.Opts{
      peers: 1,
      ssrcs: ssrcs,
      audio: false,
      video_codecs: [{:VP8, %RTPMapping{payload_type: 98, encoding: "VP8", clock_rate: 90_000}}]
    }

    SDP.create_offer(ice_ufrag, ice_pwd, dtls_fingerprint, opts) |> to_string()
  end

  def create_answer(_ice_ufrag, _ice_pwd, _fingerprint) do
    #    {:ok, sdp} = get_example_answer_sdp()
    #    prepare_sdp(sdp, ice_ufrag, ice_pwd, fingerprint)
    ""
  end
end
