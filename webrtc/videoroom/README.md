# Membrane WebRTC video room demo

This project demonstrates an example of running multiple video rooms
using WebRTC. 

It consists of a basic phoenix app which communicates with membrane pipeline (pipeline per room)
to exchange WebRTC candidates/answers. Pipeline then takes a role of the SFU, receiving and forwarding
WebRTC traffic. 

## Environmental variables

Available runtime environmental variables:
```
VIRTUAL_HOST={host passed to the endpoint config, defaults to "localhost" on non-production environments}

USE_TLS={"true" or "false", if set to "true" then https will be used and certificate paths will be required}
KEY_FILE_PATH={path to certificate key file, used when "USE_TLS" is set to true}
CERT_FILE_PATH={path to certificate file, used when "USE_TLS" is set to true}

STUN_SERVERS={list of stun servers separated by ",", defaults to a single server "stun1.l.google.com:19302"}
TURN_SERVERS={list of turn servers separated by ",", defaults to ""}
MAX_DISPLAY_NUM={maximum number of remote video tiles to send and display, defaults to "3"}
MAX_PARTICIPANTS_NUM={maximum number of participants in a single room, by default there is no limit}
```

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

### Running application

Default path for certificate files for non-production environment is `priv/certs/`.

If you want to run TLS locally you can generate certificates
as described in the [signaling server readme](https://github.com/membraneframework/membrane_demo/tree/master/webrtc/simple#https). 

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

Default environmental variables are available in `.env` file, you can adjust it to your needs.

**IMPORTANT**
If you intend to use TLS remember that setting paths in `.env` file is not enough.
Those paths will be used inside docker container therefore besides setting env variables you will need to mount those paths
to docker container on your own.

Then you can run videoroom with membrane's latest image:
```bash
docker run -p 4000:4000 --env-file .env membraneframework/demo_webrtc_videoroom:latest
```

Or build and run docker image from source:
```bash
docker build  -t membrane_videoroom .
docker run -p 4000:4000 --env-file .env membrane_videoroom 
```

Then go to <http://localhost:4000/>.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
