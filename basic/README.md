# Membrane Demo - Basic

This project contains two demos that can help understanding how to use Membrane Framework.

## Prerequisites

1. Make sure you have Elixir installed on your machine. See: https://elixir-lang.org/install.html
1. Fetch the required dependencies by running `mix deps.get`

## First Pipeline Demo

This demo shows how to create a pipeline that plays an mp3 file.

### How to run

To start the demo pipeline run `mix run --no-halt run_pipeline_demo.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
alias Membrane.Demo.BasicPipeline
{:ok, pid} = BasicPipeline.start_link("sample.mp3")
BasicPipeline.play(pid)
```

## First Element Demo

This demo shows how to create a simple element and plug it into a pipeline.

### How to run

To start the demo pipeline run `mix run --no-halt run_element_demo.exs` or type the following commands into an IEx shell (started by `iex -S mix`):


```elixir
alias Membrane.Demo.BasicElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
```

## Sample License

Sample is provided under Creative Commons. Song is called Swan Song by [Paper Navy](https://papernavy.bandcamp.com/album/all-grown-up).

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
