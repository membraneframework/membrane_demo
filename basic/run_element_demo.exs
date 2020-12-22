alias Membrane.Demo.BasicElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
