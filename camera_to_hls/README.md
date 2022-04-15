# Membrane Demo - Camera Video to HLS

This project demonstrates capturing camera video and converting it to HLS stream, which is then can be used wherever you want :)

## Prerequisites

You must have following packages installed on your system:

- ffmpeg 4.\*
- openssl

### If using MACOS and `homebrew`:

```shell
brew install ffmpeg
```

## Run the demo

Run the project with:

```bash
mix run --no-halt
```

CMAF header and segment files will be created in `output` directory along with HLS playlist files.

To play the HLS stream you can just serve the content of `output` dir via regular HTTP server, e.g. by running:

```bash
python3 -m http.server 8000
```

Then, you can open the url http://localhost:8000/output/index.m3u8 in some player, e.g. `ffplay` or `vlc`

```bash
ffplay http://localhost:8000/output/index.m3u8
```

Moreover you can open the url http://localhost:8000/stream in your browser and enjoy the video from your camera :)

_You might be asked to grant access to your camera, as some operating systems require that_

<!-- ## Technical Explanation -->
<!-- TODO -->

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
