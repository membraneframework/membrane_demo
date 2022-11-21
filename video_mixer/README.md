# Membrane video mixer demo

This demo shows how to mix audio and video files.  
Audio files in .wav format are merged to single .aac file.  
Video files in .h264 are merged into single .h264 file.

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
    apt install clang-format portaudio19-dev ffmpeg libavutil-dev libswresample-dev libmad0-dev libfdk-aac-dev
    ```
    One-liner for MacOS
    ```bash
    brew install clang-format portaudio ffmpeg libmad pkg-config fdk-aac
    ```
1. Make sure you have Elixir installed on your machine. See: https://elixir-lang.org/install.html
1. Fetch the required dependencies by running `mix deps.get`

### How to run

To start the demo run `mix run --no-halt run.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

Start AudioPipeline
```elixir
alias Membrane.Demo.AudioPipeline
{:ok, pid} = AudioPipeline.start_link({"sound_500f.wav", "sound_1000f.wav"})
AudioPipeline.play(pid)
```
Start VideoPipeline
```elixir
alias Membrane.Demo.VideoPipeline
{:ok, pid} = VideoPipeline.start_link({"video_red.h264", "video_green.h264"})
VideoPipeline.play(pid)
```

Mixed video and audio are saved in the `output.h264` and `output.aac` files, accordingly.

## FAQ

Feel free to ask questions on our [Discord server](https://discord.gg/2AzVhZTf).

## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
