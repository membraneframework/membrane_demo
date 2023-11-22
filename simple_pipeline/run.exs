{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(Membrane.Demo.SimplePipeline, "sample.mp3")
