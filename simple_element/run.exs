alias Membrane.Demo.SimpleElement.Pipeline

{:ok, _supervisor, _pid} =
  Membrane.Pipeline.start_link(Pipeline, "sample.mp3")
