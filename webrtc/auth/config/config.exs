import Config

config :example_auth,
  # WebRTC over HTTP is possible, however Chrome and Firefox require HTTPS for getUserMedia()
  scheme: :https,
  port: 8443,
  ip: {0, 0, 0, 0},
  password: "PASSWORD",
  # Attach your SSL certificate and key files here
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem",
  ecto_repos: [Example.Auth.Repo]

config :example_auth, Example.Auth.Repo,
  database: "example_auth",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: "5432"

config :example_auth, Example.Auth.UserManager.Guardian,
  issuer: "example_auth",
  # insert your secret_key here
  cookie_options: [max_age: 5],
  secret_key: "Db90hCX48LvAh3V9fdY8FYmlgwmVhfQcUP6rUE9DVal8iQizzad5KzwmKusXwKdz"
