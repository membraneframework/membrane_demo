alias Membrane.Demo.RTP.ReceivePipeline
{:ok, pid} = ReceivePipeline.start_link(%{
    secure?: "--secure" in System.argv(),
    video_port: 5000,
    audio_port: 5002
  })
ReceivePipeline.play(pid)
