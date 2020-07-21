# Membrane Demo - RTP to HLS

This project demonstrates handling RTP streams and converting them to HLS streams.

The whole idea has been described in [this blog post](https://blog.swmansion.com/live-video-streaming-in-elixir-made-simple-with-membrane-fc5b2083982d).

## Prerequisites

You must have following packages installed on your system:

- ffmpeg 4.\*

### Additional tools used by the following guide

- GStreamer > 1.0 to provide RTP streams
- python3 for running simple Web Server

## Run the demo

Create output directory inside of this demo folder:

```bash
mkdir output
```

Next run the project with:

```bash
mix run --no-halt
```

Server will start listening for UDP connections by default on port 5000.

After that you can start sending any H264 video and AAC audio stream
via RTP. Below you can see an example how to generate sample streams
with GStreamer.

```bash
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=44100 ! avenc_aac ! rtpmp4gpay  pt=127 ! udpsink host=127.0.0.1 port=5000 \
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

HLS header and segment files will be created in `output` directory along with playlist files.

To play the HLS stream you need to serve the content of `output` dir, e.g. by running:

```bash
cd output && python3 -m http.server 8000
```

Then, you can open the url `http://localhost:8000/index.m3u8` in some player, e.g. `ffplay` or `vlc`

```bash
ffplay http://localhost:8000/index.m3u8
```

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
