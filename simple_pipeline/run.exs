alias Membrane.Demo.SimplePipeline
{:ok, pid} = SimplePipeline.start_link("sample.mp3")
SimplePipeline.play(pid)
