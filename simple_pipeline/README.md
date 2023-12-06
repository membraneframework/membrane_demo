# Membrane simple pipeline demo

This demo shows how to create a pipeline that plays an mp3 file.

## Prerequisites

To run the demo, you need [Elixir installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`).

If you are running the demo on Linux, make sure to have the following dependencies installed in your system:
- portaudio19-dev,
- pkg-config 

On Ubuntu, you can install them with the following command:
```shell
apt install portaudio19-dev pkg-config
```

## Running the demo

To run the demo, clone the `membrane_demo` repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/simple_pipeline
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

To start the demo pipeline run `mix run --no-halt run.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
{:ok, _pid} = Membrane.Pipeline.start_link(Membrane.Demo.SimplePipeline, "sample.mp3")
```

Should there be any errors when compiling the script's dependencies, you may need to install the some dependencies manually on your system:
* [PortAudio](https://www.portaudio.com/) - which we use to play the audio
* [FFmpeg](https://ffmpeg.org/) - which we use to resample the audio
* [MAD](https://www.underbit.com/products/mad/) - which is used to decode audio


## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
