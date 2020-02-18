# Membrane Demo - RTP

This project demonstrates handling RTP in Membrane.

This example uses [RTP bin](https://github.com/membraneframework/membrane-bin-rtp) that is responsible for
receiving and interpreting RTP streams.

## Bins

This demo is also a presentation of a new Membrane v0.5 feature: Bins.

Bins are entities that enable creating reusable, dynamically customisable groups of elements.
Bins can spawn their children like pipelines and have pads like elements, so they can be
embedded within a pipeline (or another bin). Bins' pads proxy the stream between their siblings and children.

## Prerequisites

You have to have installed the following packages on your system:

* FFmpeg 4.x
* SDL 2
* PortAudio

## Run the demo

To run this project, type

```bash
mix run --no-halt
```

It will start a server listening for UDP connections on port 5000.

Then, you can send any h.264 video or mp3 audio via RTP to have them played. Examples below show how to generate a sample RTP stream with GStreamer.

```bash
# For audio
gst-launch-1.0 -v audiotestsrc ! lamemp3enc ! rtpmpapay pt=127 ! udpsink host=127.0.0.1 port=5000

# For video
gst-launch-1.0 -v videotestsrc ! video/x-raw,format=I420 ! x264enc ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

You should be able to see an SDL player showing an example video and hear a sample audio.

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
