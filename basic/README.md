# Membrane Demo - Basic

This project contains two demos that can help understanding how to use Membrane Framework.

## Prerequisites

1. Make sure you have Elixir installed on your machine. See: https://elixir-lang.org/install.html
1. Fetch the required dependencies by running `mix deps.get`

## First Pipeline Demo

### How to run

To start the demo pipeline run `mix run --no-halt run_pipeline_demo.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
alias Membrane.Demo.Basic.MP3.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
```

## First Element Demo

### How to run

To start the demo pipeline run `mix run --no-halt run_element_demo.exs` or type the following commands into an IEx shell (started by `iex -S mix`):


```elixir
alias Membrane.Demo.Basic.FirstElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
```

## Sample License

Sample is provided under Creative Commons. Song is called Swan Song by [Paper Navy](https://papernavy.bandcamp.com/album/all-grown-up).

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
