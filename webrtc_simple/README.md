# Membrane Demo - WebRTC Singaling Server 

Simple example of signaling server based on `Membrane.WebRTC.Server`.

## Configuration

Custom ip, port or other Plug options can be set up in `config/config.exs`. 

Download dependencies with

```
$ mix deps.get
```

### HTTPS

Since application uses HTTPS, certificate and key are needed to run it. You generate them with

```
$ openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in browser.

To trust self-signed certificate follow instructions below:

### Debian

```
$ apt install ca-certificates
$ cp priv/certs/certificate.pem /usr/local/share/ca-certificates/
$ update-ca-certificates
```

### Arch

```
$ trust anchor --store priv/certs/certificate.pem
```

### MacOS

```
$ security import priv/certs/certificate.pem -k ~/Library/Keychains/login.keychain-db
```

Then, find your certificate in Keychains, open it, expand the Trust section and change
the SSL setting to "Always Trust".

## Usage

Run application with

```
$ mix start
```

You can join videochat in: 
`https://YOUR-IP-ADDRESS:PORT/NAME-OF-ROOM`, for example [here](https://localhost:8443/room). You should see 
video stream from your and every other peer cameras.

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
