# RTSP to HLS converter demo

This project demonstrates receiving RTSP stream and converting it to HLS stream.

## Prerequisites

In order to run this demo you have to run it on a machine with a publicly visible ip address, with a `docker-compose` installed.

## Components
The project consists of 3 parts:

* Converter - Given RTSP stream uses `Membrane.RTSP` plugin to set-up RTP to HLS pipeline.
* Server - Nginx-based application to serve HLS related static files.
* Player - Nginx-based application to serve HTML with player working with `hls.js`

## Running the demo

You can use `docker-compose` to set up all containers.
You need to set `PUBLIC_IP` environment variable in the `.env` file.

The ip should be the public ip address of your machine.

You can then run the demo:
```console
docker-compose up
```

After a few seconds you will be able to view the sample stream by going to `PUBLIC_IP:8000` in the browser.

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)