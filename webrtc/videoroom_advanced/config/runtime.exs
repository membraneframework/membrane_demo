import Config

defmodule ConfigParser do
  def parse_stun_servers(""), do: []

  def parse_stun_servers(servers) do
    servers
    |> String.split(",")
    |> Enum.map(fn server ->
      with [addr, port] <- String.split(server, ":"),
           {port, ""} <- Integer.parse(port) do
        %{server_addr: parse_addr(addr), server_port: port}
      else
        _ -> raise("Bad STUN server format. Expected addr:port, got: #{inspect(server)}")
      end
    end)
  end

  def parse_turn_settings(settings) do
    optional_error_message = """
    "Bad TURN servers settings format. Expected addr:secret:cert or addr:secret, got: \
    #{inspect(settings)}
    """

    settings
    |> String.split(":")
    |> then(fn
      [ip | tail] ->
        {:ok, ip} = ip |> to_charlist() |> :inet.parse_address()
        [ip | tail]

      _ ->
        raise(optional_error_message)
    end)
    |> then(fn
      [ip, secret] ->
        [ip: ip, secret: secret]

      [ip, secret, cert] ->
        [ip: ip, secret: secret, cert: cert]

      _ ->
        raise(optional_error_message)
    end)
    |> IO.inspect(label: "dupa parse_turn_settings")
  end

  def parse_addr(addr) do
    case :inet.parse_address(String.to_charlist(addr)) do
      {:ok, ip} -> ip
      # FQDN?
      {:error, :einval} -> addr
    end
  end
end

# stun_servers: "addr:port"
# turn_settings: "addr:secret"
# turn_settings: "addr:secret:cert"
config :membrane_videoroom_demo,
  stun_servers:
    System.get_env("STUN_SERVERS", "64.233.163.127:19302") |> ConfigParser.parse_stun_servers(),
  turn_settings:
    System.get_env("TURN_SETTINGS", "127.0.0.1:abc") |> ConfigParser.parse_turn_settings()

protocol = if System.get_env("USE_TLS") == "true", do: :https, else: :http

get_env = fn env, default ->
  if config_env() == :prod do
    System.fetch_env!(env)
  else
    System.get_env(env, default)
  end
end

host = get_env.("VIRTUAL_HOST", "localhost")
port = 4000

args =
  if protocol == :https do
    [
      keyfile: get_env.("KEY_FILE_PATH", "priv/certs/key.pem"),
      certfile: get_env.("CERT_FILE_PATH", "priv/certs/certificate.pem"),
      cipher_suite: :strong
    ]
  else
    []
  end
  |> Keyword.merge(otp_app: :membrane_videoroom_demo, port: port)

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
  {:url, [host: host]},
  {protocol, args}
]
