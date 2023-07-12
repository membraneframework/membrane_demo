# Membrane Demo - WebRTC Singaling Server

An example of signaling server with authentication based on `Membrane.WebRTC.Server`.

## Prerequisites and running the demo

Below is the instruction for the installation of required dependencies and how to run this demo on various operating systems:

<details>
<summary>
<b>macOS</b>
</summary>

### Prerequisites

Make sure you have `postgresql` installed on your computer.

```shell
brew install postgresql
```

Then run the database server:

```shell
brew services start postgresql
```

Furthermore, make sure you have Elixir installed on your machine. For installation details, see: https://elixir-lang.org/install.html

### Running the demo

To run the demo, clone the `membrane_demo` repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/webrtc_authentication
```

Custom database's IP, port, name and other `Plug` options can be set up in `config/config.exs`.

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

#### Guardian

This application uses [Guardian](https://github.com/ueberauth/guardian) to authenticate
the users. Generate your secret key with:

```shell
mix guardian.gen.secret
```

and add it to the config file (`config/config.exs`).

#### Database

Configure database in `config/config.exs`.

> In case you are not sure about the configuration that should be passed in `config/config.exs`, you can try to connect with your database with the use of `psql`.

Then, create a database for the application:

```shell
mix ecto.create
```

and migrate the users table:

```shell
mix ecto.migrate
```

Finally, create one or more users:

```elixir
iex -S mix
iex> Example.Auth.UserManager.create_user(%{username: "username", password: "password"})
```

If you want to connect to the application outside of your local network, you need to set up
TURN and STUN servers. Insert their URLs in `rtcConfig` in `priv/static/js/main.js`.

#### HTTPS

Since application uses HTTPS, certificate and key are needed to run it. You generate them with

```shell
openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in browser.

To trust self-signed certificate follow instructions below:

```shell
security import priv/certs/certificate.pem -k ~/Library/Keychains/login.keychain-db
```

Then, find your certificate in Keychains, open it, expand the Trust section and change
the SSL setting to "Always Trust".

### Usage

Run application with:

```shell
mix start
```

You can join videochat in: `https://YOUR-IP-ADDRESS:PORT/` (by default, it will be
https://0.0.0.0:8443/). After logging in, you should see video stream from your and every other
peer cameras.

_You might be asked to grant access to your camera, as some operating systems require that._

_In case of the absence of a physical camera, it is necessary to use a virtual camera (e.g. OBS, [see how to set up the virtual camera in OBS](https://obsproject.com/kb/virtual-camera-guide))_

</details>

<details>
<summary>
<b>Ubuntu</b>
</summary>

### Prerequisites

Make sure you have `postgresql` installed on your computer.

```shell
sudo apt-get install postgresql
```

Then run the database server:

```shell
sudo service postgresql start
```

Furthermore, make sure you have Elixir installed on your machine. For installation details, see: https://elixir-lang.org/install.html

On Ubuntu, we recommend installation through `asdf`, see: https://asdf-vm.com/guide/getting-started.html

### Running the demo

To run the demo, clone the `membrane_demo` repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/webrtc_authentication
```

Custom database's IP, port, name and other `Plug` options can be set up in `config/config.exs`.

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

> In case of installation issues with Hex on Ubuntu, try updating the system packages first by entering the command:
>
> ```shell
> sudo apt-get update
> ```

#### Guardian

This application uses [Guardian](https://github.com/ueberauth/guardian) to authenticate
the users. Generate your secret key with:

```shell
mix guardian.gen.secret
```

and add it to the config file (`config/config.exs`).

#### Database

Configure database in `config/config.exs`.

> In case you are not sure about the configuration that should be passed in `config/config.exs`, you can try to connect with your database with the use of `psql`.

Then, create a database for the application:

```shell
mix ecto.create
```

and migrate the users table:

```shell
mix ecto.migrate
```

Finally, create one or more users:

```elixir
iex -S mix
iex> Example.Auth.UserManager.create_user(%{username: "username", password: "password"})
```

If you want to connect to the application outside of your local network, you need to set up
TURN and STUN servers. Insert their URLs in `rtcConfig` in `priv/static/js/main.js`.

#### HTTPS

Since application uses HTTPS, certificate and key are needed to run it. You generate them with

```shell
openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in browser.

To trust self-signed certificate follow instructions below:

```shell
apt install ca-certificates
cp priv/certs/certificate.pem /usr/local/share/ca-certificates/
update-ca-certificates
```

### Usage

Run application with:

```shell
mix start
```

You can join videochat in: `https://YOUR-IP-ADDRESS:PORT/` (by default, it will be
https://0.0.0.0:8443/). After logging in, you should see video stream from your and every other
peer cameras.

_You might be asked to grant access to your camera, as some operating systems require that._

_In case of the absence of a physical camera, it is necessary to use a virtual camera (e.g. OBS, [see how to set up the virtual camera in OBS](https://obsproject.com/kb/virtual-camera-guide))_

</details>

<details>
<summary>
<b>Arch</b>
</summary>

### Prerequisites

Make sure you have `postgresql` installed on your computer.

```shell
sudo pacman -S postgresql
```

Then run the database server:

```shell
sudo systemctl start postgresql
```

Furthermore, make sure you have Elixir installed on your machine. For installation details, see: https://elixir-lang.org/install.html

### Running the demo

To run the demo, clone the `membrane_demo` repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/webrtc_authentication
```

Custom database's IP, port, name and other `Plug` options can be set up in `config/config.exs`.

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and then `rebar3`.

#### Guardian

This application uses [Guardian](https://github.com/ueberauth/guardian) to authenticate
the users. Generate your secret key with:

```shell
mix guardian.gen.secret
```

and add it to the config file (`config/config.exs`).

#### Database

Configure database in `config/config.exs`.

> In case you are not sure about the configuration that should be passed in `config/config.exs`, you can try to connect with your database with the use of `psql`.

Then, create a database for the application:

```shell
mix ecto.create
```

and migrate the users table:

```shell
mix ecto.migrate
```

Finally, create one or more users:

```elixir
iex -S mix
iex> Example.Auth.UserManager.create_user(%{username: "username", password: "password"})
```

If you want to connect to the application outside of your local network, you need to set up
TURN and STUN servers. Insert their URLs in `rtcConfig` in `priv/static/js/main.js`.

#### HTTPS

Since application uses HTTPS, certificate and key are needed to run it. You generate them with

```shell
openssl req -newkey rsa:2048 -nodes -keyout priv/certs/key.pem -x509 -days 365 -out priv/certs/certificate.pem
```

Note that this certificate is not validated and thus may cause warnings in browser.

To trust self-signed certificate follow instructions below:

```shell
trust anchor --store priv/certs/certificate.pem
```

### Usage

Run application with:

```shell
mix start
```

You can join videochat in: `https://YOUR-IP-ADDRESS:PORT/` (by default, it will be
https://0.0.0.0:8443/). After logging in, you should see video stream from your and every other
peer cameras.

_You might be asked to grant access to your camera, as some operating systems require that._

_In case of the absence of a physical camera, it is necessary to use a virtual camera (e.g. OBS, [see how to set up the virtual camera in OBS](https://obsproject.com/kb/virtual-camera-guide))_

</details>

## Copyright and License

Copyright 2019, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
