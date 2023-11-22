alias Membrane.Demo.RTP.SendPipeline

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(SendPipeline, %{
    video_port: 5000,
    video_ssrc: 1234,
    audio_port: 5002,
    audio_ssrc: 1236,
    secure?: "--secure" in System.argv(),
    srtp_key: String.duplicate("a", 30)
  })
