import Config

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint,
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

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/videoroom_web/(live|views)/.*(ex)$",
      ~r"lib/videoroom_web/templates/.*(eex)$"
    ]
  ]

config :logger, level: :info
