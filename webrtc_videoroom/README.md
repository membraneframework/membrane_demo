# Membrane WebRTC video room demo

This project demonstrates an example usage of Membrane SFU API defined in [membrane_sfu](https://github.com/membraneframework/membrane_sfu).

## Run manually

### Dependencies

In order to run phoenix application manually you will need to have `node` installed.
Demo has been tested with `node` version `v14.15.0`. You will also need some system dependencies.

#### Mac OS X

```
brew install srtp libnice clang-format ffmpeg opus
```

#### Ubuntu

```
sudo apt-get install libsrtp2-dev libnice-dev libavcodec-dev libavformat-dev libavutil-dev libopus-dev
```

### To run
First install all dependencies:
```
mix deps.get
npm ci --prefix=assets
```

In order to run, type:

```
mix phx.server 
```

Then go to <http://localhost:4000/>.

## Run with docker

Videoroom demo provides a `Dockerfile` that you can use to run videoroom application yourself without any additional setup and dependencies.

### To run:

```bash
docker run -p 4000:4000 membraneframework/demo_webrtc_videoroom:latest
```

Or build and run docker image from source:
```bash
docker build  -t membrane_videoroom .
docker run -p 4000:4000 membrane_videoroom 
```

Then go to <http://localhost:4000/>.

## Run distributed

Videoroom demo does not automatically start a cluster, but you can check the distributed functionalities by starting one manually.

Open two terminals. On the first run:

```bash
$ SERVER_PORT=4001 iex --sname one -S mix phx.server
```

On the second, run:

```bash
$ SERVER_PORT=4002 iex --sname two -S mix phx.server
```

This will start two videoroom instances, one running on port `4001` on node `one@{your-local-hostname}`
and the other on port `4002` on node `two@{your-local-hostname}`.

To create a cluster, run this on the first terminal:

```elixir
iex(one@{your-local-hostname})1> :net_kernel.connect_node(:'two@{your-local-hostname}')
true
```

You can check that the cluster has been created with:

```elixir
iex(one@{your-local-hostname})2> :erlang.nodes()                     
[:two@{your-local-hostname}]
```

Then, open two tabs on your browser. Go to <http://localhost:4001/> on one, and <http://localhost:4002/> on the other.
Join the same room, and you shall see two participants in the room. Every participant EndPoint will be running on their respective node.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
