# Membrane simple element demo

This demo shows how to create a simple Membrane element and plug it into a pipeline.

## Prerequisites and running the demo

Below is the instruction for the installation of required dependencies and how to run this demo on various operating systems:

<details>
<summary>
<b>macOS</b>
</summary>

### Prerequisites

To run the demo, you need [Elixir installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`).

### Running the demo

To run the demo, clone the `membrane_demo` repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/simple_element
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

To start the demo pipeline run `mix run --no-halt run.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
Membrane.Pipeline.start_link(Membrane.Demo.SimpleElement.Pipeline, "sample.mp3")
```

You should hear the audio sample playing and see the number of buffers processed being periodically printed to the console.

Should there be any errors when compiling the script's dependencies, you may need to install the some dependencies manually on your system:
* [PortAudio](https://www.portaudio.com/) - which we use to play the audio
* [FFmpeg](https://ffmpeg.org/) - which we use to resample the audio
* [MAD](https://www.underbit.com/products/mad/) - which is used to decode audio

## How it works

The pipeline takes a sample mp3 file, decodes it, and plays the audio.
The simple `counter` element is responsible for counting the number of buffers
passing through it and periodically prints the number of buffers processed to the console.

The element is plugged in just before the audio player element in the pipeline.

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
