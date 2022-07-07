import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :rtmp_to_hls, RtmpToHlsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "7QKtyBTigBZGpLDW0nc1U44mpE1U9kQzDd60hynU4bcnAUfLXPJLQxRlde8fPDhb",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
