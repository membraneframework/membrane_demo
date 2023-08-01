# Membrane simple pipeline demo

This demo shows how to create a pipeline that plays an mp3 file.

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
cd membrane_demo/simple_pipeline
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

To start the demo pipeline run `mix run --no-halt run.exs` or type the following commands into an IEx shell (started by `iex -S mix`):

```elixir
{:ok, _pid} = Membrane.Demo.SimplePipeline.start_link("sample.mp3")
```

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
cd membrane_demo/simple_pipeline
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
{:ok, _pid} = Membrane.Demo.SimplePipeline.start_link("sample.mp3")
```

</details>

## Sample License

The sample is provided under Creative Commons. Song is called Swan Song by [Paper Navy](https://papernavy.bandcamp.com/album/all-grown-up).

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
