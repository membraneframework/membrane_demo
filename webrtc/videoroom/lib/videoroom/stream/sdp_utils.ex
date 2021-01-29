defmodule VideoRoom.Stream.SDPUtils do
  def get_remote_credentials(sdp) do
    attributes = List.first(sdp.media).attributes

    attributes =
      attributes
      |> Enum.reject(fn %ExSDP.Attribute{key: key} -> key not in ["ice-ufrag", "ice-pwd"] end)

    %ExSDP.Attribute{value: ice_ufrag} =
      attributes |> Enum.find(fn %ExSDP.Attribute{key: key} -> key == "ice-ufrag" end)

    %ExSDP.Attribute{value: ice_pwd} =
      attributes |> Enum.find(fn %ExSDP.Attribute{key: key} -> key == "ice-pwd" end)

    ice_ufrag <> " " <> ice_pwd
  end

  def create_offer(ice_ufrag, ice_pwd, fingerprint) do
    {:ok, sdp} = get_example_offer_sdp()
    prepare_sdp(sdp, ice_ufrag, ice_pwd, fingerprint)
  end

  defp prepare_sdp(sdp, ice_ufrag, ice_pwd, fingerprint) do
    media =
      sdp.media
      |> Enum.map(fn m ->
        new_attr =
          m.attributes
          |> Enum.map(fn %ExSDP.Attribute{key: key} = a ->
            case key do
              "ice-ufrag" -> %ExSDP.Attribute{a | value: ice_ufrag}
              "ice-pwd" -> %ExSDP.Attribute{a | value: ice_pwd}
              "fingerprint" -> %ExSDP.Attribute{a | value: "sha-256 " <> fingerprint}
              _ -> a
            end
          end)

        %ExSDP.Media{m | attributes: new_attr}
      end)

    %ExSDP{sdp | media: media} |> ExSDP.serialize()
  end

  def get_example_offer_sdp() do
    streams = Enum.to_list(0..3)

    """
    v=0
    o=- 7263753815578774817 2 IN IP4 127.0.0.1
    s=-
    t=0 0
    a=group:BUNDLE #{Enum.map_join(streams, " ", &"audio#{&1}")} #{
      Enum.map_join(streams, " ", &"video#{&1}")
    }
    a=msid-semantic: WMS *
    #{sdp_stream(:audio, "recvonly", hd(streams))}
    #{Enum.map_join(tl(streams), &sdp_stream(:audio, "sendonly", &1))}
    #{sdp_stream(:video, "recvonly", hd(streams))}
    #{Enum.map_join(tl(streams), &sdp_stream(:video, "sendonly", &1))}
    """
    |> String.replace("\n\n", "\n")
    |> String.replace("\n\n", "\n")
    |> ExSDP.parse()
  end

  defp sdp_stream(:audio, mode, id) do
    """
    m=audio 9 UDP/TLS/RTP/SAVPF 120
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:audio#{id}
    a=#{mode}
    a=msid:stream#{id} stream#{id}-audio
    a=rtcp-mux
    a=rtpmap:120 opus/48000/2
    a=fmtp:120 minptime=10;useinbandfec=1
    a=ssrc:1#{id}0 cname:stream#{id}
    """
  end

  defp sdp_stream(:video, mode, id) do
    """
    m=video 9 UDP/TLS/RTP/SAVPF 96
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:video#{id}
    a=#{mode}
    a=msid:stream#{id} stream#{id}-video
    a=rtcp-mux
    a=rtcp-rsize
    a=rtpmap:96 H264/90000
    a=rtcp-fb:96 ccm fir
    a=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f
    a=ssrc-group:FID 2#{id}0 2#{id}1
    a=ssrc:2#{id}0 cname:stream#{id}
    a=ssrc:2#{id}1 cname:stream#{id}
    """
  end
end
