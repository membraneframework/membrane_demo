import Config

config :echo_demo,
  ip: {0, 0, 0, 0},
  port: 8443,
  keyfile: "priv/certs/key.pem",
  certfile: "priv/certs/certificate.pem"

config :logger,
  level: :info,
  compile_time_purge_matching: [
    [level_lower_than: :info],
    # Silence warnings caused by in-band RTCP that we don't support yet
    [module: Membrane.SRTP.Decryptor, function: "handle_process/4", level_lower_than: :error]
  ]

config :membrane_timescaledb_reporter, Membrane.Telemetry.TimescaleDB.Repo,
  database: "membrane_timescaledb_reporter",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  chunk_time_interval: "3 second",
  chunk_compress_policy_interval: "1 second"

config :membrane_timescaledb_reporter, ecto_repos: [Membrane.Telemetry.TimescaleDB.Repo]

config :logger, :console, metadata: [:room]
