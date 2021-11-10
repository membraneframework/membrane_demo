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

  def parse_turn_servers(""), do: []

  def parse_turn_servers(servers) do
    servers
    |> String.split(",")
    |> Enum.map(fn server ->
      with [addr, port, username, password, proto] when proto in ["udp", "tcp", "tls"] <-
             String.split(server, ":"),
           {port, ""} <- Integer.parse(port) do
        %{
          server_addr: parse_addr(addr),
          server_port: port,
          username: username,
          password: password,
          relay_type: String.to_atom(proto)
        }
      else
        _ ->
          raise("""
          "Bad TURN server format. Expected addr:port:username:password:proto, got: \
          #{inspect(server)}
          """)
      end
    end)
  end

  def parse_integrated_turn_ip(ip) do
    with {:ok, parsed_ip} <- ip |> to_charlist() |> :inet.parse_address() do
      parsed_ip
    else
      _ ->
        raise("""
        Bad integrated TURN IP format. Expected IPv4, got: \
        #{inspect(ip)}
        """)
    end
  end

  def parse_use_integrated_turn("true"), do: true
  def parse_use_integrated_turn("false"), do: false

  def parse_use_integrated_turn(env) do
    raise("""
    Bad USE_INTEGRATED_TURN enviroment variable value. Expected "true" or "false", got: \
    #{inspect(env)}
    """)
  end

  def parse_addr(addr) do
    case :inet.parse_address(String.to_charlist(addr)) do
      {:ok, ip} -> ip
      # FQDN?
      {:error, :einval} -> addr
    end
  end
end

config :membrane_videoroom_demo,
  stun_servers:
    System.get_env("STUN_SERVERS", "64.233.163.127:19302") |> ConfigParser.parse_stun_servers(),
  turn_servers: System.get_env("TURN_SERVERS", "") |> ConfigParser.parse_turn_servers(),
  use_integrated_turn:
    System.get_env("USE_INTEGRATED_TURN", "false") |> ConfigParser.parse_use_integrated_turn(),
  integrated_turn_ip:
    System.get_env("INTEGRATED_TURN_IP", "127.0.0.1") |> ConfigParser.parse_integrated_turn_ip()

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
