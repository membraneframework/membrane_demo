import Config

config :membrane_videoroom_demo,
  stun_servers: System.get_env("STUN_SERVERS", "64.233.163.127:19302") |> String.split(",")

protocol = if System.get_env("USE_TLS") == "true", do: :https, else: :http

{host, port, args} =
  if config_env() == :prod do
    host = System.fetch_env!("HOST")
    port = System.fetch_env!("PORT") |> String.to_integer()

    args =
      if protocol == :https do
        [
          keyfile: System.fetch_env!("KEY_FILE_PATH"),
          certfile: System.fetch_env!("CERT_FILE_PATH"),
          cipher_suite: :strong
        ]
      else
        []
      end

    {host, port, args}
  else
    host = System.get_env("HOST", "localhost")
    default_port = if protocol == :https, do: "8433", else: "8000"
    port = System.get_env("PORT", default_port) |> String.to_integer()

    args =
      if protocol == :https do
        [
          keyfile: System.get_env("KEY_FILE_PATH", "priv/certs/key.pem"),
          certfile: System.get_env("CERT_FILE_PATH", "priv/certs/certificate.pem"),
          cipher_suite: :strong
        ]
      else
        []
      end

    {host, port, args}
  end

args = Keyword.merge([otp_app: :membrane_videoroom_demo, port: port], args)

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
  {:url, [host: host]},
  {protocol, args}
]
