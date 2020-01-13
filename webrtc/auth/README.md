# Membrane Demo - WebRTC Singaling Server 

An example of signaling server with authentication based on `Membrane.WebRTC.Server`.

## Configuration

Custom ip, port or other Plug options can be set up in `config/config.exs`. 

Download dependencies with

```
$ mix deps.get
```

### Guardian

This application uses [Guardian](https://github.com/ueberauth/guardian) to authenticate 
the users. Generate your secret key with

```
$ mix guardian.gen.secret
```

and add it to the config file (`config/config.exs`). Then, migrate the users table

```
$ mix ecto.migrate
```

And finally, create one or more users

```
$ iex -S mix
iex> Example.Auth.UserManager.create_user(%{username: "username", password: "password"})
```

If you want to connect to the application outside of your local network, you need to set up 
TURN and STUN servers. Insert their URLs in `rtcConfig` in `priv/static/js/main.js`.
 
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

You can join videochat in: `https://YOUR-IP-ADDRESS:PORT/` (by default, it will be 
https://0.0.0.0:8443/). After logging in, you should see video stream from your and every other
peer cameras.

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
