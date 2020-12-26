# Membrane WebRTC recording demo

App recording 10-second h264 video from the browser. Tested only on Chrome. 

## Dependencies

### Mac OS X

```
brew install srtp libnice clang-format ffmpeg
```

## Usage

Firstly, generate certificate, as described in the [signaling server readme](https://github.com/membraneframework/membrane_demo/tree/master/webrtc/simple#https). 

In order to run, type:

```
mix deps.get
mix run --no-halt
```

Then, go to <https://localhost:8443/>.

IP, port and friends can be set in `config/config.exs`.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
