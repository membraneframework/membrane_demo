# Membrane Demo - RTP

This project demonstrates handling RTP in Membrane.

This example uses [RTP plugin](https://github.com/membraneframework/membrane_rtp_plugin) that is responsible for receiving and sending RTP streams.

## Running the demo

To run the demo, you'll need to have [Elixir installed](https://elixir-lang.org/install.html). Then, do the following:

- Open a terminal in the project directory
- Type `mix deps.get` to download dependencies
- Type `mix run receive.exs` to run the receiving pipeline
- Wait until the script runs
- Open another terminal in the project directory
- Type `mix run send.exs` to run the sending pipeline

You should be able to see a player showing an example video.

The sender pipeline (run with `send.exs`) takes sample audio and video files and sends them via RTP.
The receiving pipeline (run with `receive.exs`) receives the audio and video streams and plays them.

If you wish to stream using SRTP, add a `--secure` flag when running both `receive.exs` and `send.exs`.

You can also use another tool, like [GStreamer](https://gstreamer.freedesktop.org/), to send the stream. In this case, you only need to start the receiving pipeline:

```shell
mix run receive.exs
```

and launch GStreamer:

```shell
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=48000,channels=2 ! opusenc ! rtpopuspay pt=120 ! udpsink host=127.0.0.1 port=5002\
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```

## Copyright and License

Copyright 2018, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
