alias Membrane.Demo.RTP.ReceivePipeline
{:ok, pid} = ReceivePipeline.start_link(%{
    secure?: "--secure" in System.argv(),
    port: 5000,
    fmt_mapping: %{96 => {:H264, 90_000}}
  })
ReceivePipeline.play(pid)
