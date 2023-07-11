# Membrane Demo - RTP to HLS

This project demonstrates handling RTP streams and converting them to HLS streams.

The whole idea has been described in [this blog post](https://blog.swmansion.com/live-video-streaming-in-elixir-made-simple-with-membrane-fc5b2083982d).

## Prerequisites and running the demo

Below is the instruction for the installation of required dependencies and how to run this demo on various operating systems:

<details>
<summary>
<b>macOS</b>
</summary>

### Prerequisites

You must have following packages installed on your system:

- FFmpeg 4.\*
- GStreamer > 1.0 to provide RTP streams
- python3 for running simple Web Server

```shell
brew install ffmpeg gstreamer python3
```

Furthermore, make sure you have `Elixir` and `Erlang` installed on your machine. For installation details, see: https://elixir-lang.org/install.html

### Run the demo

To run the demo, clone the membrane_demo repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/rtp_to_hls
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

> In case of issues with compilation of membrane_h264_ffmpeg_plugin, enter:
>
> ```shell
> mix deps.update bundlex
> ```
>
> and then install pkg-config:
>
> ```shell
> brew install pkg-config
> ```

Finally ,you can run the demo with:

```shell
mix run --no-halt
```

Server will start listening for UDP connections by default on port 5000.

After that you can start sending any H264 video and AAC audio stream
via RTP. Below you can see an example how to generate sample streams
with GStreamer.

```shell
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=44100 ! faac ! rtpmp4gpay  pt=127 ! udpsink host=127.0.0.1 port=5000 \
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

HLS header and segment files will be created in `output` directory along with playlist files.

To play the HLS stream you need to serve the content of `output` dir, e.g. by running:

```shell
cd output && python3 -m http.server 8000
```

Then, you can open the url `http://localhost:8000/index.m3u8` in some player, e.g. `ffplay` or `vlc`

```shell
ffplay http://localhost:8000/index.m3u8
```

</details>

<details>
<summary>
<b>Ubuntu</b>
</summary>

### Prerequisites

You must have following packages installed on your system:

- FFmpeg 4.\*
- GStreamer > 1.0 to provide RTP streams
- python3 for running simple Web Server

```shell
apt install ffmpeg gstreamer python3
```

Furthermore, make sure you have `Elixir` and `Erlang` installed on your machine. For installation details, see: https://elixir-lang.org/install.html

On Ubuntu, we recommend installation through `asdf`, see: https://asdf-vm.com/guide/getting-started.html

### Run the demo

To run the demo, clone the membrane_demo repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/rtp_to_hls
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

> In case of issues with compilation of membrane_h264_ffmpeg_plugin, enter:
>
> ```shell
> mix deps.update bundlex
> ```

Finally ,you can run the demo with:

```shell
mix run --no-halt
```

Server will start listening for UDP connections by default on port 5000.

After that you can start sending any H264 video and AAC audio stream
via RTP. Below you can see an example how to generate sample streams
with GStreamer.

```shell
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=44100 ! faac ! rtpmp4gpay  pt=127 ! udpsink host=127.0.0.1 port=5000 \
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

HLS header and segment files will be created in `output` directory along with playlist files.

To play the HLS stream you need to serve the content of `output` dir, e.g. by running:

```shell
cd output && python3 -m http.server 8000
```

Then, you can open the url `http://localhost:8000/index.m3u8` in some player, e.g. `ffplay` or `vlc`

```shell
ffplay http://localhost:8000/index.m3u8
```

</details>

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
