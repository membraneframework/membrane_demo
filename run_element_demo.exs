alias Membrane.Demo.FirstElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
