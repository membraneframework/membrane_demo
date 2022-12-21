# RTSP to HLS converter demo

This demo demonstrates receiving RTSP stream and converting it to HLS stream.

## Components
The project consists of 2 parts:

- The pipeline, which converts the RTP stream to HLS
- Connection Manager, which is started by the pipeline and is responsible for establishing RTSP connection

The internal architecture of an application is presented below:

![Application scheme](doc_assets/RTSP_to_HLS_pipeline.png)

## Prerequisites

1. In order to run this demo you have to run it on a machine with a publicly visible ip address.

2. Make sure you have [ffmpeg](https://www.ffmpeg.org/) installed on your machine - you are going to
use it to play the stream. We advise to use ffmpeg 5.0 or newer.

Ubuntu
```console
apt install ffmpeg
```

Mac OS
```console
brew install ffmpeg
```

3. Furthermore, make sure you have Elixir installed on your machine. For installation details, see: https://elixir-lang.org/install.html

## Running the demo
You can configure the parameters for the converter in the `Application` module:
##### lib/application.ex
```elixir
@rtsp_stream_url "rtsp://rtsp.membrane.work:554/testsrc.264"
@output_path "hls_output"
@rtp_port 20000
```
By default we use our sample RTSP stream at rtsp.membrane.work.


To run the demo, clone the `membrane_demo` repository and checkout to the demo directory:

```console
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/rtsp_to_hls
```

Then you need to download the dependencies of the mix project:
```console
mix deps.get
```

You can start the pipeline by running:
```console
mix run --no-halt
```

After a moment the pipeline will start generating HLS output files. In order to watch the stream we need to serve those files, e.g. by using python http server:

```console
python3 -m http.server 8000
```

You can then play the stream using ffmpeg:

```console
ffplay http://YOUR_SERVER_IP/hls_output/index.m3u8
```

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
