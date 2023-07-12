# Membrane simple element demo

This demo shows how to create a simple Membrane element and plug it into a pipeline.

## Prerequisites and running the demo

Below is the instruction for the installation of required dependencies and how to run this demo on various operating systems:

<details>
<summary>
<b>macOS</b>
</summary>

### Prerequisites

Make sure you have the following libraries installed on your OS:

- clang-format,
- portaudio19-dev,
- FFmpeg 4.\*,
- libavutil-dev,
- libswresample-dev,
- libmad0-dev

```shell
brew install clang-format portaudio ffmpeg libmad pkg-config
```

Furthermore, make sure you have Elixir installed on your machine. For installation details, see: https://elixir-lang.org/install.html

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
alias Membrane.Demo.SimpleElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
```

You should hear the audio sample playing and see the number of buffers processed being periodically printed to the console.

</details>

<details>
<summary>
<b>Ubuntu</b>
</summary>

### Prerequisites

Make sure you have the following libraries installed on your OS:

- clang-format,
- portaudio19-dev,
- FFmpeg 4.\*,
- libavutil-dev,
- libswresample-dev,
- libmad0-dev

```shell
apt install clang-format portaudio19-dev ffmpeg libavutil-dev libswresample-dev libmad0-dev
```

Furthermore, make sure you have Elixir installed on your machine. For installation details, see: https://elixir-lang.org/install.html

On Ubuntu, we recommend installation through `asdf`, see: https://asdf-vm.com/guide/getting-started.html

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

> In case of installation issues with Hex on Ubuntu, try updating the system packages first by entering the command:
>
> ```shell
> sudo apt-get update
> ```

To start the demo pipeline run `mix run --no-halt run.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
alias Membrane.Demo.SimpleElement.Pipeline
{:ok, pid} = Pipeline.start_link("sample.mp3")
```

You should hear the audio sample playing and see the number of buffers processed being periodically printed to the console.

</details>

## How it works

The pipeline takes a sample mp3 file, decodes it, and plays the audio.
The simple `counter` element is responsible for counting the number of buffers
passing through it and periodically prints the number of buffers processed to the console.

The element is plugged in just before the audio player element in the pipeline.

## Sample License

The sample is provided under Creative Commons. Song is called Swan Song by [Paper Navy](https://papernavy.bandcamp.com/album/all-grown-up).

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
