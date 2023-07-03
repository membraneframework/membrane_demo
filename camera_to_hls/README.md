# Membrane Demo - Camera Video to HLS

This project demonstrates capturing camera video and converting it to HLS stream, which is then can be used wherever you want :)

## Prerequisites and running the demo

Below is the instruction for the installation of required dependencies and how to run this demo on various operating systems:

<details>
<summary>
<b>MacOS</b>
</summary>

### Prerequisites

You must have following packages installed on your system:

- FFmpeg 4.\*
- openssl

Furthermore, make sure you have `Elixir` and `Erlang` installed on your machine. For installation details, see: https://elixir-lang.org/install.html

```shell
brew install ffmpeg openssl
```

### Run the demo

To run the demo, clone the membrane_demo repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/camera_to_hls
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and `rebar3`.

Finally, you can run the project with:

```shell
mix run --no-halt
```

CMAF header and segment files will be created in `output` directory along with HLS playlist files.

To play the HLS stream you can just serve the content of `output` dir via regular HTTP server, e.g. by running in a separate terminal:

```shell
python3 -m http.server 8000
```

Then, you can open the url http://localhost:8000/output/index.m3u8 in some player, e.g. `ffplay` or `vlc`

```shell
ffplay http://localhost:8000/output/index.m3u8
```

Moreover you can open the url http://localhost:8000/stream in your browser and enjoy the video from your camera :)

_You might be asked to grant access to your camera, as some operating systems require that_

_In case of the absence of a physical camera, it is necessary to use a virtual camera (e.g. OBS, [see how to set up the virtual camera in OBS](https://obsproject.com/kb/virtual-camera-guide))_

</details>

<details>
<summary>
<b>Ubuntu</b>
</summary>

### Prerequisites

You must have following packages installed on your system:

- FFmpeg 4.\*
- openssl

Furthermore, make sure you have `Elixir` and `Erlang` installed on your machine. For installation details, see: https://elixir-lang.org/install.html

On Ubuntu, we recommend installation through `asdf`, see: https://asdf-vm.com/guide/getting-started.html

```shell
apt install ffmpeg
```

### Run the demo

To run the demo, clone the membrane_demo repository and checkout to the demo directory:

```shell
git clone https://github.com/membraneframework/membrane_demo
cd membrane_demo/camera_to_hls
```

Then you need to download the dependencies of the mix project:

```shell
mix deps.get
```

You may be asked to install `Hex` and `rebar3`.
In case of installation issues with `Hex` on Ubuntu, try updating the system packages first by entering the command:

```shell
sudo apt-get update
```

Finally, you can run the project with:

```shell
mix run --no-halt
```

CMAF header and segment files will be created in `output` directory along with HLS playlist files.

To play the HLS stream you can just serve the content of `output` dir via regular HTTP server, e.g. by running in a separate terminal:

```shell
python3 -m http.server 8000
```

Then, you can open the url http://localhost:8000/output/index.m3u8 in some player, e.g. `ffplay` or `vlc`

```shell
ffplay http://localhost:8000/output/index.m3u8
```

Moreover you can open the url http://localhost:8000/stream in your browser and enjoy the video from your camera :)

_You might be asked to grant access to your camera, as some operating systems require that_

_In case of the absence of a physical camera, it is necessary to use a virtual camera (e.g. OBS, [see how to set up the virtual camera in OBS](https://obsproject.com/kb/virtual-camera-guide))_

</details>
<br>

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
