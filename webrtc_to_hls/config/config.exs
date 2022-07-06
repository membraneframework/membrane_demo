import Config

config :phoenix, :json_library, Jason

config :esbuild,
  version: "0.12.15",
  default: [
    args:
      ~w(src/index.ts --bundle --target=es2016 --outfile=../priv/static/assets/js/app.js --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :membrane_webrtc_to_hls_demo, WebRTCToHLSWeb.Endpoint, pubsub_server: WebRTCToHLS.PubSub

config :membrane_webrtc_to_hls_demo, version: System.get_env("VERSION", "unknown")

config :membrane_webrtc_to_hls_demo, hls_output_mount_path: "output"

config :logger,
  compile_time_purge_matching: [
    [level_lower_than: :debug],
    # Silence irrelevant warnings caused by resending handshake events
    [module: Membrane.SRTP.Encryptor, function: "handle_event/4", level_lower_than: :error]
  ]

config :logger, :console, metadata: [:room, :peer]

import_config("#{config_env()}.exs")
