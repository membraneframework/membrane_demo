import Config

config :membrane_videoroom_demo,
  ip: {0, 0, 0, 0},
  port: 8443,
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem"

config :phoenix, :json_library, Jason

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint,
  url: [host: "localhost"],
  pubsub_server: VideoRoom.PubSub,
  https: [
    port: 8443,
    cipher_suite: :strong,
    otp_app: :membrane_videoroom_demo,
    keyfile: "priv/certs/key.pem",
    certfile: "priv/certs/certificate.pem"
  ],
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

config :logger,
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :info],
    # Silence irrelevant warnings caused by resending handshake events
    [module: Membrane.SRTP.Encryptor, function: "handle_event/4", level_lower_than: :error]
  ]

config :logger, :console, metadata: [:room]
