# RTP to HLS

This project demonstrates handling RTP streams and converting them to HLS streams.

The whole idea has been described in [this blog post](https://blog.swmansion.com/live-video-streaming-in-elixir-made-simple-with-membrane-fc5b2083982d).

## Running the demo

To run the demo, you'll need to have [Elixir installed](https://elixir-lang.org/install.html). Then, run

```shell
elixir rtp_to_hls.exs
```

After a while, the server will start listening for UDP connections on port 5000. Then, start the RTP stream with

```shell
elixir send.exs
```

When the server prints that playback is available, visit `http://localhost:8000/stream.html` and you should see the stream there. The stream can be also played with players other than the browser, like `vlc` or `ffplay`, for example

```bash
ffplay http://localhost:8000/output/index.m3u8
```

The RTP stream can be sent with other tools as well, for example with [GStreamer](https://gstreamer.freedesktop.org/):

```shell
gst-launch-1.0 -v audiotestsrc ! audio/x-raw,rate=44100 ! faac ! rtpmp4gpay  pt=127 ! udpsink host=127.0.0.1 port=5000 \
    videotestsrc ! video/x-raw,format=I420 ! x264enc key-int-max=10 tune=zerolatency ! rtph264pay pt=96 ! udpsink host=127.0.0.1 port=5000
```


## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
