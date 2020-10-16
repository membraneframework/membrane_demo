alias Membrane.Demo.RTP.SendPipeline
{:ok, pid} = SendPipeline.start_link(%{
    secure?: "--secure" in System.argv(),
    port: 5000,
    ssrc: 1234,
    fmt_mapping: %{96 => {:H264, 90_000}}
  })
SendPipeline.play(pid)
