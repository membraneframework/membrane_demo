import Config

config :membrane_webrtc_to_hls_demo, WebRTCToHLSWeb.Endpoint,
  code_reloader: true,
  watchers: [
    esbuild:
      {Esbuild, :install_and_run,
       [
         :default,
         ~w(--sourcemap=inline --bundle --watch)
       ]},
    npx: [
      "tailwindcss",
      "--input=css/app.css",
      "--output=../priv/static/assets/css/app.css",
      "--postcss",
      "--watch",
      cd: Path.expand("../assets", __DIR__)
    ]
  ]

config :membrane_webrtc_to_hls_demo, WebRTCToHLSWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/WebRTCToHLS_web/(live|views)/.*(ex)$",
      ~r"lib/WebRTCToHLS_web/templates/.*(eex)$"
    ]
  ]

config :logger, level: :info
