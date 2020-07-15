# Membrane Demo - RTP to HLS
This project demonstrates handling RTP streams and converting them to HLS streams.

The whole idea has been described in [this blog post](https://blog.swmansion.com/live-video-streaming-in-elixir-made-simple-with-membrane-fc5b2083982d).

## Prerequisites
You must have following packages installed on your system:

* jpeg-turbo
* ffmpeg 4.*


## Run the demo
Create output directory inside of this demo folder:

```bash
mkdir -p output
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
# audio stream
gst-launch-1.0 -v audiotestsrc ! avenc_aac ! rtpmp4gpay  pt=127 ! udpsink host=127.0.0.1 port=5000

# video stream
gst-launch-1.0 -v videotestsrc ! video/x-raw,format=I420 ! x264enc ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

HLS header and segment files will be accordingly created in `output` directory.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)

