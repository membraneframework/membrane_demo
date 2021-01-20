defmodule EchoDemo.Echo.SDPUtils do
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

  defp get_example_offer_sdp() do
    """
    v=0
    o=- 7263753815578774817 2 IN IP4 127.0.0.1
    s=-
    t=0 0
    a=group:BUNDLE audio1 audio2 audio3 video1 video2 video3
    a=msid-semantic: WMS *
    m=audio 9 UDP/TLS/RTP/SAVPF 120
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:audio1
    a=sendrecv
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANS 0c68dcf5-db98-4c3f-b0f2-ff1918ed80b1
    a=rtcp-mux
    a=rtpmap:120 opus/48000/2
    a=fmtp:120 minptime=10;useinbandfec=1
    a=ssrc:110 cname:stream1
    m=audio 9 UDP/TLS/RTP/SAVPF 120
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:audio2
    a=sendonly
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANT 0c68dcf5-db98-4c3f-b0f2-ff1918ed80b2
    a=rtcp-mux
    a=rtpmap:120 opus/48000/2
    a=fmtp:120 minptime=10;useinbandfec=1
    a=ssrc:120 cname:stream2
    m=audio 9 UDP/TLS/RTP/SAVPF 120
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:audio3
    a=sendonly
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANU 0c68dcf5-db98-4c3f-b0f2-ff1918ed80b3
    a=rtcp-mux
    a=rtpmap:120 opus/48000/2
    a=fmtp:120 minptime=10;useinbandfec=1
    a=ssrc:130 cname:stream3
    m=video 9 UDP/TLS/RTP/SAVPF 96
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:video1
    a=sendrecv
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANS a60cccca-f708-49e7-89d0-4be0524658a5
    a=rtcp-mux
    a=rtcp-rsize
    a=rtpmap:96 H264/90000
    a=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f
    a=ssrc-group:FID 210 211
    a=ssrc:210 cname:stream1
    a=ssrc:211 cname:stream1
    m=video 9 UDP/TLS/RTP/SAVPF 96
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:video2
    a=sendonly
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANT a60cccca-f708-49e7-89d0-4be0524658a6
    a=rtcp-mux
    a=rtcp-rsize
    a=rtpmap:96 H264/90000
    a=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f
    a=ssrc-group:FID 220 221
    a=ssrc:220 cname:stream2
    a=ssrc:221 cname:stream2
    m=video 9 UDP/TLS/RTP/SAVPF 96
    c=IN IP4 0.0.0.0
    a=rtcp:9 IN IP4 0.0.0.0
    a=ice-ufrag:1PSY
    a=ice-pwd:ejBMY08jZ4EWoJbIfuJsgRIS
    a=ice-options:trickle
    a=fingerprint:sha-256 24:2D:06:61:0E:59:54:0E:69:08:A4:9F:0A:D9:17:4B:89:50:11:A2:20:65:68:0B:61:11:51:57:EA:F6:11:E4
    a=setup:actpass
    a=mid:video3
    a=sendonly
    a=msid:0YiRg3sIeAEZEhwD3ANvRbn7UFf3BjYBeANU a60cccca-f708-49e7-89d0-4be0524658a7
    a=rtcp-mux
    a=rtcp-rsize
    a=rtpmap:96 H264/90000
    a=fmtp:96 level-asymmetry-allowed=1;packetization-mode=1;profile-level-id=42e01f
    a=ssrc-group:FID 230 231
    a=ssrc:230 cname:stream3
    a=ssrc:231 cname:stream3
    """
    |> ExSDP.parse()
  end
end
