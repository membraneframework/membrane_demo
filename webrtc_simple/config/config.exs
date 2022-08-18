import Config

config :example_simple,
  # WebRTC over HTTP is possible, however Chrome and Firefox require HTTPS for getUserMedia()
  scheme: :https,
  port: 8443,
  ip: {0, 0, 0, 0},
  password: "PASSWORD",
  otp_app: :example_simple,
  # Attach your SSL certificate and key files here
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem"
