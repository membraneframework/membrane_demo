# Membrane Demo - RTP

This project demonstrates handling RTP in Membrane.

This example uses [RTP plugin](https://github.com/membraneframework/membrane_rtp_plugin) that is responsible for
receiving and sending RTP streams.

## Prerequisites and running the demo

Below is the instruction for the installation of required dependencies and how to run this demo on various operating systems:

<details>
<summary>
<b>macOS</b>
</summary>

### Prerequisites

Make sure you have the following packages installed in your system:

- FFmpeg 4.x
- SDL 2
- PortAudio

```shell
brew install ffmpeg portaudio sdl2
```

Furthermore, make sure you have `Elixir` and `Erlang` installed on your machine. For installation details, see: https://elixir-lang.org/install.html

### Run the demo

To run the demo, clone the membrane_demo repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/rtp
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

> In case of issues with the compilation of ex_libsrtp, enter:
>
> ```shell
> mix deps.update bundlex
> ```
>
> and then install pkg-config and srtp:
>
> ```shell
> brew install pkg-config srtp
> ```

> In case of issues with compilation of membrane_opus_plugin, install `opus`:
>
> ```shell
> brew install opus
> ```
>
> and if you have macOS M1/M2 (Apple silicon) add following lines to your `~/.zshrc` file:
>
> ```shell
> export C_INCLUDE_PATH=$C_INCLUDE_PATH:$(brew --cellar)/opus/1.3.1/include
> export LIBRARY_PATH=$LIBRARY_PATH:$(brew --cellar)/opus/1.3.1/lib
> ```
>
> and restart your terminal.

Finally, you can run the demo:

- Open a terminal in the project directory
- Type: `mix run --no-halt receive.exs`
- Open another terminal in the project directory
- Type: `mix run --no-halt send.exs`

You should be able to see an SDL player showing an example video.

The sender pipeline (run with `send.exs`) takes sample audio and video files and sends them with RTP.
The receiving pipeline (run with `receive.exs`) depayloads the audio and video streams and plays them.

If you wish to stream using SRTP, add a `--secure` flag when running both `receive.exs` and `send.exs`.

Alternatively, the stream can be sent using [gstreamer](https://gstreamer.freedesktop.org/). In this case, you only need to start the receiving pipeline:

```shell
mix run --no-halt receive.exs
```

and launch gstreamer:

```shell
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=48000,channels=2 ! opusenc ! rtpopuspay pt=120 ! udpsink host=127.0.0.1 port=5002\
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

</details>

<details>
<summary>
<b>Ubuntu</b>
</summary>

### Prerequisites

Make sure you have the following packages installed in your system:

- FFmpeg 4.x
- SDL 2
- PortAudio

```shell
apt install ffmpeg portaudio19-dev libsdl2-dev
```

Furthermore, make sure you have `Elixir` and `Erlang` installed on your machine. For installation details, see: https://elixir-lang.org/install.html

On Ubuntu, we recommend installation through `asdf`, see: https://asdf-vm.com/guide/getting-started.html

### Run the demo

To run the demo, clone the membrane_demo repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/rtp
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

> In case of issues with the compilation of ex_libsrtp, enter:
>
> ```shell
> mix deps.update bundlex
> ```

> In case of issues with compilation of membrane_opus_plugin, install `opus`:
>
> ```shell
> apt install libopus-dev
> ```
>
> and then install `libavcodec`:
>
> ```shell
> apt install libavcodec-dev
> ```

Finally, you can run the demo:

- Open a terminal in the project directory
- Type: `mix run --no-halt receive.exs`
- Open another terminal in the project directory
- Type: `mix run --no-halt send.exs`

You should be able to see an SDL player showing an example video.

The sender pipeline (run with `send.exs`) takes sample audio and video files and sends them with RTP.
The receiving pipeline (run with `receive.exs`) depayloads the audio and video streams and plays them.

If you wish to stream using SRTP, add a `--secure` flag when running both `receive.exs` and `send.exs`.

Alternatively, the stream can be sent using [gstreamer](https://gstreamer.freedesktop.org/). In this case, you only need to start the receiving pipeline:

```shell
mix run --no-halt receive.exs
```

and launch gstreamer:

```shell
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=48000,channels=2 ! opusenc ! rtpopuspay pt=120 ! udpsink host=127.0.0.1 port=5002\
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

</details>

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
