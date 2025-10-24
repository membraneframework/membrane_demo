# Audio mixing

This script demonstrates mixing two audio tracks

To run the demo, you need [Elixir installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`). Then, run

```bash
elixir mix_audio.exs
```

and it will generate `output.aac`, that you can play with VLC or other player.

Should there be any errors when compiling the script's dependencies, you may need to install [FDK AAC](https://github.com/mstorsjo/fdk-aac), which we use to encode the output stream.


## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://docs.membrane.stream/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
