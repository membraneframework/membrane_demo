# Membrane simple element demo

This demo shows how to create a simple element and plug it into a pipeline.
The pipeline is taken from the `simple_pipeline` demo.

## Prerequisites

1. Make sure you have following libraries installed on your OS:
   * clang-format, 
   * portaudio19-dev, 
   * ffmpeg, 
   * libavutil-dev, 
   * libswresample-dev, 
   * libmad0-dev
   
    One-liner for Ubuntu
    ```bash
    apt install clang-format portaudio19-dev ffmpeg libavutil-dev libswresample-dev libmad0-dev
    ```
    One-liner for MacOS
    ```bash
    brew install clang-format portaudio ffmpeg libmad pkg-config
    ```
1. Make sure you have Elixir installed on your machine. See: https://elixir-lang.org/install.html
1. Fetch the required dependencies by running `mix deps.get`

### How to run

To start the demo pipeline run `mix run --no-halt run.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
alias Membrane.Demo.SimpleElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
Pipeline.play(pid)
```

## Sample License

Sample is provided under Creative Commons. Song is called Swan Song by [Paper Navy](https://papernavy.bandcamp.com/album/all-grown-up).

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
