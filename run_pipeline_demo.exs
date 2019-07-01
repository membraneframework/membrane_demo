alias Membrane.Demo.MP3.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
