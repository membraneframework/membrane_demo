alias Membrane.Demo.RTP.SendPipeline
{:ok, pid} = SendPipeline.start_link(%{
    secure?: "--secure" in System.argv(),
    video_port: 5000,
    video_ssrc: 1234,
    audio_port: 5002,
    audio_ssrc: 1236
  })
SendPipeline.play(pid)
