# Membrane WebRTC video room advanced demo

This project demonstrates an advanced example usage of Membrane SFU API defined in [membrane_sfu](https://github.com/membraneframework/membrane_sfu).

## Environment variables
Available runtime environment variables:
```
VIRTUAL_HOST={host passed to the endpoint config, defaults to "localhost" on non-production environments}

USE_TLS={"true" or "false", if set to "true" then https will be used and certificate paths will be required}
KEY_FILE_PATH={path to certificate key file, used when "USE_TLS" is set to true}
CERT_FILE_PATH={path to certificate file, used when "USE_TLS" is set to true}

STUN_SERVERS={list of stun servers separated by ",", defaults to a single server "stun1.l.google.com:19302"}
TURN_SERVERS={list of turn servers separated by ",", defaults to ""}
USE_INTEGRATED_TURN={"true" or "false", if set to "true", then integrated TURN servers will be used}
INTEGRATED_TURN_IP={turn server ip}
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

Videoroom demo provides a `Dockerfile** that you can use to run videoroom application yourself without any additional setup and dependencies.

### To run:

Default environmental variables are available in .env file, you can adjust it to your needs.

**IMPORTANT** If you intend to use TLS remember that setting paths in .env file is not enough. Those paths will be used inside docker container therefore besides setting env variables you will need to mount those paths to docker container on your own.

```bash
docker run -p 4000:4000 --env-file .env membraneframework/demo_webrtc_videoroom_advanced:latest
```

Or build and run docker image from source:
```bash
docker build  -t membrane_videoroom_advanced .
docker run -p 4000:4000 --env-file .env membrane_videoroom_advanced 
```

Then go to <http://localhost:4000/>.

### To run with OpenTelemetry

By default OpenTelemetry is turn off. You can turn it on by going `config/runtime.exs` and change `otel_state` to one of four possible values:

* :purge - default value, OpenTelemetry is turned off
* :local - OpenTelemetry traces will be printed on stdout
* :zipkin - OpenTelemetry traces are send to zipkin. You can change the url on which traces are sent in `config/runtime.exs`. To setup zipkin you can run this command `docker run -d -p 9411:9411 openzipkin/zipkin`.
* :honeycomb - OpenTelemetry traces are send to Honeycomb. You have to specify "x-honeycomb-team", which is API KEY for this service.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
