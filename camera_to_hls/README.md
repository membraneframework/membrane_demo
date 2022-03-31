# Membrane Demo - Camera Video to HLS

This project demonstrates handling camera video and converting it to HLS stream, which is then can be used wherever you want :)

## Prerequisites

You must have following packages installed on your system:

- ffmpeg 4.\*

### If using MACOS and `homebrew`:

```shell
brew install ffmpeg
```

## Run the demo

Run the project with:

```bash
mix run --no-halt
```

HLS header and segment files will be created in `output` directory along with playlist files.

To play the HLS stream you need to serve the content of `output` dir, e.g. by running:

```bash
cd output && python3 -m http.server 8000
```

Then, you can open the url `http://localhost:8000/index.m3u8` in some player, e.g. `ffplay` or `vlc`

```bash
ffplay http://localhost:8000/index.m3u8
```

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
