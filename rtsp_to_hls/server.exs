rtsp_server_port = 8554
rtp_server_port = 30003
fixture_path = "assets/video.mp4"

{:ok, _server} =
  Membrane.RTSP.Server.start_link(
    handler: Membrane.Demo.RTSPToHLS.Server.Handler,
    handler_config: %{fixture_path: fixture_path},
    port: rtsp_server_port,
    address: {127, 0, 0, 1},
    udp_rtp_port: rtp_server_port,
    udp_rtcp_port: rtp_server_port + 1
  )

Membrane.SimpleRTSPServer.start_link("assets/video.mp4")

Process.sleep(:infinity)
