import Config

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint,
  watchers: [
    node: [
      "node_modules/webpack/bin/webpack.js",
      "--mode",
      "development",
      "--watch-stdin",
      cd: Path.expand("../assets", __DIR__)
    ]
  ],
  code_reloader: true,
  live_reload: [
    dirs: [
      "priv/static",
      "lib/videoroom_web/controllers",
      "lib/videoroom_web/views",
      "lib/videoroom_web/templates"
    ]
  ]

config :logger, level: :debug
