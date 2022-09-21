alias Membrane.Demo.RTP.ReceivePipeline

{:ok, _pid} =
  ReceivePipeline.start_link(%{
    secure?: "--secure" in System.argv(),
    video_port: 5000,
    audio_port: 5002
  })
