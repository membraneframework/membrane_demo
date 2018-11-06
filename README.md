# Membrane Demo

This repository contains two demos that can help understanding how to use Membrane Framework.

## First Pipeline Demo

### How to run

To start the demo pipeline run the following commands in `iex -S mix`:

```
{:ok, pid} = Membrane.Pipeline.start_link(Membrane.Demo.MP3.Pipeline, "sample.mp3")
Membrane.Pipeline.play(pid)
```

## First Element Demo

### How to run

To start the "first element" demo, run the following commands in `iex -S mix`:

```
{:ok, pid} = Membrane.Pipeline.start_link(Membrane.Demo.FirstElement.Pipeline, "sample.mp3")
Membrane.Pipeline.play(pid)
```






