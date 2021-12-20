import Config

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
  {:url, [host: "localhost"]},
  {:http, [otp_app: :membrane_videoroom_demo, port: System.get_env("SERVER_PORT") || 4000]}
]
