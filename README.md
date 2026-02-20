# Membrane Demo

The simplest way to start using Membrane is via [Boombox](https://github.com/membraneframework/boombox/) - see [examples](https://hexdocs.pm/boombox/examples.html). This repo contains examples of using Membrane directly.

In the subdirectories of this repository you can find the following examples of using Membrane:


- [simple_element](https://github.com/membraneframework/membrane_demo/tree/master/simple_element) - an example of a simple Membrane's element capable of counting the incoming buffers
- [simple_pipeline](https://github.com/membraneframework/membrane_demo/tree/master/simple_pipeline) - an example of a Membrane's pipeline playing an mp3 file
- [camera_to_hls](https://github.com/membraneframework/membrane_demo/tree/master/camera_to_hls) - a demonstration of capturing camera output and converting it to an HLS stream
- [camera_to_hls_nerves](https://github.com/membraneframework/membrane_demo/tree/master/camera_to_hls_nerves) - a demonstration of capturing video from a camera module on Raspberry Pi running Nerves and broadcasting it to a browser via HLS
- [rtmp_to_hls](https://github.com/membraneframework/membrane_demo/tree/master/rtmp_to_hls) - receiving RTMP stream and broadcasting it via HLS
- [rtmp_to_adaptive_hls](https://github.com/membraneframework/membrane_demo/tree/master/rtmp_to_adaptive_hls) - receiving RTMP stream and broadcasting via multi-bitrate adaptive HLS
- [rtp](https://github.com/membraneframework/membrane_demo/tree/master/rtp) - sending and receiving RTP/SRTP stream
- [rtp_to_hls](https://github.com/membraneframework/membrane_demo/tree/master/rtp_to_hls) - receiving RTP stream and broadcasting it via HLS
- [rtsp_to_hls](https://github.com/membraneframework/membrane_demo/tree/master/rtsp_to_hls) - receiving RTSP stream and converting it to HLS

Also, there are some [Livebook](https://livebook.dev) examples located in [livebooks](https://github.com/membraneframework/membrane_demo/tree/master/livebooks) directory:

- [openai_realtime_with_membrane_webrtc](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/openai_realtime_with_membrane_webrtc) - conversation with AI via browser using [OpenAI Realtime API](https://openai.com/index/introducing-the-realtime-api/)
- [speech_to_text](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/speech_to_text) - real-time speech recognition using [Whisper](https://github.com/openai/whisper)
- [audio_mixer](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/audio_mixer) - mix a beep sound into background music
- [messages_source_and_sink](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/messages_source_and_sink) - send and receive media from the pipeline via Elixir messages
- [playing_mp3_file](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/playing_mp3_file) - play an mp3 file in a Livebook cell
- [rtmp](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/rtmp) - send and receive RTMP stream
- [soundwave](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/soundwave) - plot live audio amplitude on a graph

## Authors

Membrane Framework is created by Software Mansion.

Since 2012 [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane) is a software agency with experience in building web and mobile apps as well as complex multimedia solutions. We are Core React Native Contributors and experts in live streaming and broadcasting technologies. We can help you build your next dream product – [Hire us](https://swmansion.com/contact/projects).

Copyright 2024, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)

[Livebook]: https://livebook.dev
