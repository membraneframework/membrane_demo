# RTSP to HLS converter

Application to convert RTSP streams into HLS format.

### Project contains 3 parts:

* Converter - Given RTSP stream uses `Membrane.RTSP` plugin to set-up RTP to HLS pipeline. Contains API and simple dashboard to manage streams.
* Server - Nginx-based application to serve HLS related static files.
* Player - Nginx-based application to serve HTML with player working with `hls.js`

### Converter

Docker container with volume shared with server container.
You need to set up `SECRET_KEY_BASE`, `AUTH_USERNAME` and `AUTH_PASSWORD` and provide working credentials to your PG database. `UDP_PORT_RANGE` is a range of ports used for UDP connection with rtsp endpoints. It determines amount of streams converter is able to convert. Each RTSP connection needs to neighbour ports so e.g. range 20000-20060 means that we can manage 30 streams. Be carefull with that and choose wisely. Providing wide range may cause docker to time-out during container start as docker is opening socket for each of those ports by default.

```bash
docker run \
  -e UDP_PORT_RANGE=20000-20060 \
  -e PLAYER_BASE_URL=http://95.217.182.18:8000 \
  -e SERVER_BASE_URL=http://95.217.182.18:8080 \
  -e CONVERTER_BASE_URL=http://95.217.182.18:4000 \
  -v output:/app/output \
  -p 4000:4000 \
  hls_proxy_api
```

### Server

Nginx-based docker container with shared volume:

```bash
docker run \
  -e PLAYER_BASE_URL=http://localhost:8000 \
  -v output:/hls_output \
  -p 8000:8000 \
  hls_proxy_server
```

### Player

Nginx-based docker container:

```bash
docker run \
  -e SERVER_BASE_URL=http://localhost:8080 \
  -p 8000:8080 \
  hls_proxy_player
```

## docker-compose

You can use `docker-compose` to set up all containers.
You need following ENV vars to be passed to `docker-compose up` command:

- `SERVER_BASE_URL` & `PLAYER_BASE_URL` & `CONVERTER_BASE_URL`
