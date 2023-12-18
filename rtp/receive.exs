alias Membrane.Demo.RTP.ReceivePipeline

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(ReceivePipeline, %{
    video_port: 5000,
    audio_port: 5002,
    secure?: "--secure" in System.argv(),
    srtp_key: String.duplicate("a", 30)
  })

Process.sleep(:infinity)
