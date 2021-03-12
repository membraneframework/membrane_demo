# Membrane WebRTC video room demo

## Dependencies

In order to run phoenix application you will need to have `node` installed.
Demo has been tested with `node` version `v14.15.0`.

### Mac OS X

```
brew install srtp libnice clang-format ffmpeg opus
```


## Usage

Available runtime environmental variables:
```
HOST={host passed to the endpoint config, defaults to "localhost" on non-production environments}
PORT={port used to run phoenix server, defaults to "8443" for https and "8000" for http}

USE_TLS={"true" or "false", if set to "true" then https will be used and certificate paths will be required}
KEY_FILE_PATH={path to certificate key file, used when "USE_TLS" is set to true}
CERT_FILE_PATH={path to certificate file, used when "USE_TLS" is set to true}
```

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

Then, go to <http://localhost:8000/>.

## Copyright and License

Copyright 2020, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
