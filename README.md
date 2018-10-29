# Sample Membrane Pipeline

## How to run

To start the project run `iex -S mix`. It will start an interactive shell with project loaded.

Then run following:
```
{:ok, pid} = Membrane.Pipeline.start_link(MembraneMP3Demo.Pipeline, "sample.mp3", [])
```

It will prepare pipeline to start.

Run `Membrane.Pipeline.play(pid)` to start and `Membrane.Pipeline.stop(pid)`