alias Membrane.Demo.BasicPipeline
{:ok, pid} = BasicPipeline.start_link("sample.mp3")
BasicPipeline.play(pid)
