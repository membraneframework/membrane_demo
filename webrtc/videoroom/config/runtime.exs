import Config

protocol = if System.get_env("USE_TLS") == "true", do: :https, else: :http

default_args = [
  otp_app: :membrane_videoroom_demo
]

if config_env() == :prod do
  host = System.fetch_env!("HOST")
  port = System.fetch_env!("PORT") |> String.to_integer()

  args =
    if protocol == :https do
      [
        port: port,
        keyfile: System.fetch_env!("KEY_FILE_PATH"),
        certfile: System.fetch_env!("CERT_FILE_PATH"),
        cipher_suite: :strong
      ]
    else
      [port: port]
    end

  args = default_args |> Keyword.merge(args)

  config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
    {:url, [host: host]},
    {protocol, args}
  ]
end

if config_env() != :prod do
  host = System.get_env("HOST", "localhost")

  args =
    if protocol == :https do
      [
        cipher_suite: :strong,
        port: System.get_env("PORT", "8443") |> String.to_integer(),
        keyfile: System.get_env("KEY_FILE_PATH", "priv/certs/key.pem"),
        certfile: System.get_env("CERT_FILE_PATH", "priv/certs/certificate.pem")
      ]
    else
      [port: System.get_env("PORT", "8000") |> String.to_integer()]
    end

  args = default_args |> Keyword.merge(args)

  config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
    {:url, [host: host]},
    {protocol, args}
  ]
end
