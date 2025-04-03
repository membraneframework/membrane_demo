# Membrane Demo - WebRTC LiveView

This project demonstrates how to use Membrane WebRTC with dedicated Phoenix LiveViews.

This example uses [WebRTC plugin](https://github.com/membraneframework/membrane_webrtc_plugin) that is responsible for receiving and sending mutlimedia via WebRTC.

Membrane modules defined in this project are placed in `lib/webrtc_live_view/pipeline.ex` and `lib/webrtc_live_view/contours_drawer.ex`.
The Phoenix LiveViews dedicated to Membrane WebRTC are used in the file lib/webrtc_live_view_web/live/home.ex.

## Running the demo

To run the demo, you'll need to have [Elixir installed](https://elixir-lang.org/install.html). Then, do the following:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Copyright and License

Copyright 2025, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://membraneframework.github.io/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
