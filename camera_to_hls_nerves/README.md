# Membrane Demo - Camera Video to HLS on Nerves

This demo demonstrates capturing video from a camera module on Raspberry Pi running Nerves and broadcasting it to a browser via HLS.

## Hardware Prerequisites

To run this demo you'll need a Raspberry Pi and a official Raspberry Pi camera module. Currently the following devices are supported:

* Raspberry Pi 4 Model B

## Software Prerequisites

<details>
<summary>
<b>MacOS</b>
</summary>

To run the demo, you need [Elixir and Erlang installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`). Additionally the following Homebrew command will install all the required packages for nerves to work:

```bash
brew update
brew install fwup squashfs coreutils xz pkg-config
```

Then you'll need to add `nerves_bootstrap` archive to your Mix environment by running

```bash
mix archive.install hex nerves_bootstrap
```

If any problems occur refer to [Nerves installation guide](https://hexdocs.pm/nerves/installation.html) for more information.

</details>

<details>
<summary>
<b>Debian-based linux</b>
</summary>

To run the demo, you need [Elixir and Erlang installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`). Additionally the following commands will install all the required packages for nerves to work:

```bash
sudo apt install build-essential automake autoconf git squashfs-tools ssh-askpass pkg-config curl libmnl-dev
sudo curl -L https://github.com/fwup-home/fwup/releases/download/v1.10.1/fwup_1.10.1_amd64.deb -o fwup_1.10.1_amd64.deb
sudo dpkg -i fwup_1.10.1_amd64.deb
sudo rm fwup_1.10.1_amd64.deb
```

Then you'll need to add `nerves_bootstrap` archive to your Mix environment by running

```bash
mix archive.install hex nerves_bootstrap
```

If any problems occur refer to [Nerves installation guide](https://hexdocs.pm/nerves/installation.html) for more information.

</details>

<details>
<summary>
<b>Arch-based linux</b>
</summary>

To run the demo, you need [Elixir and Erlang installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`). Additionally the following yay command will install all the required packages for nerves to work:

```bash
yay -S base-devel ncurses5-compat-libs openssh-askpass git squashfs-tools curl fwup
```

Then you'll need to add `nerves_bootstrap` archive to your Mix environment by running

```bash
mix archive.install hex nerves_bootstrap
```

If any problems occur refer to [Nerves installation guide](https://hexdocs.pm/nerves/installation.html) for more information.

</details>

## Targets

Nerves applications produce images for hardware targets based on the `MIX_TARGET` environment variable. Targets are represented by a short name like `rpi4` that maps to a Nerves system image for that platform. All of this logic is in the generated `mix.exs` and may be customized. For more information about targets see the [Nerves targets guide](https://hexdocs.pm/nerves/targets.html).

This demo is suitable for the following targets:
  * rpi4

## Running the demo

To run the demo:
  * `export MIX_TARGET=my_target` or prefix every command with
    `MIX_TARGET=my_target`. For example, `MIX_TARGET=rpi4`
  * `export SSID=my_wifi_ssid` and (optionally) `export PSK=my_wifi_password`. This will allow the target to connect to the network that you should also be on to access the broadcast
  * Install dependencies with `mix deps.get`
  * Create firmware with `mix firmware`
  * Burn to an SD card with `mix burn`
  * Put the SD card into the target and turn it on
  * Go to `http://nerves.local:8000/stream.html` and wait for the stream.

  The stream can be also played with players other than the browser, like vlc or ffplay, for example

  ```bash
  ffplay http://nerves.local:8000/data/output/index.m3u8
  ```

<details>
<summary>
<b>Debugging</b>
</summary>

If any problems occur you can connect to the device and manually inspect the issue. 

One of the possible options is connection by ssh. For this option to be available you have to have any ssh keys in the `~/.ssh` directory. Then, if your target connected to your network correctly and the device you'll be connecting with is also on the same network, run

```bash
ssh nerves.local
```

You should see a Nerves homescreen and an iex prompt. If you see an information `camera_to_hls_nerves not started` it means that the application crashed on start. You can then access the logs by running `RingLogger.next`. If the reason for the crash was `** (RuntimeError) libcamera-vid error, exit status: <exit_status>` then there was a problem with accessing the camera with `libcamera-vid` (one of the `rpicam-apps`). You can try opening the camera manually with `cmd "libcamera-vid -t 3000 -o /data/output.h264"` and see if any errors are logged. For more information about `rpicam-apps` refer to the [Raspberry Pi's documentation](https://www.raspberrypi.com/documentation/computers/camera_software.html).

You can also connect to your device with HDMI cable and USB keyboard, which could be useful if your device didn't connect to your network. Networking is implemented by the `vintage_net` package, so in case of networking issues refer to it's [documentation](https://hexdocs.pm/vintage_net).

For more information about connecting to Nerves targets refer to the [Nerves guide](https://hexdocs.pm/nerves/connecting-to-a-nerves-target.html).

</details>

## Copyright and License

Copyright 2023, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
