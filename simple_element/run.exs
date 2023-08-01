alias Membrane.Demo.SimpleElement.Pipeline
{:ok, _supervisor, _pid} = Pipeline.start_link("sample.mp3")
