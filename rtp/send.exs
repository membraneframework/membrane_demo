alias Membrane.Demo.RTP.SendPipeline

{:ok, _pid} =
  SendPipeline.start_link(%{
    secure?: "--secure" in System.argv(),
    video_port: 5000,
    video_ssrc: 1234,
    audio_port: 5002,
    audio_ssrc: 1236,
    audio_file: "audio.raw"
  })
