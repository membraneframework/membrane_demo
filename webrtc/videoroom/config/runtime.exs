import Config

defmodule ConfigParser do
  def parse_max_participants_num(nil), do: nil

  def parse_max_participants_num(max_display_num_raw) do
    case Integer.parse(max_display_num_raw) do
      {max_display_num, ""} when max_display_num_raw > 0 ->
        max_display_num

      _ ->
        raise """
        Expected MAX_PARTICIPANTS_NUM to be string representing positive integer,
        got: #{inspect(max_display_num_raw)}
        """
    end
  end

  def parse_max_display_num(max_display_num_raw) do
    case Integer.parse(max_display_num_raw) do
      {max_display_num, ""} when max_display_num > 0 ->
        max_display_num

      _ ->
        raise("""
        Expected MAX_DISPLAY_NUM to be string representing positive integer,
        got: #{inspect(max_display_num_raw)}
        """)
    end
  end

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
          proto: String.to_atom(proto)
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

  def parse_addr(addr) do
    case :inet.parse_address(String.to_charlist(addr)) do
      {:ok, ip} -> ip
      # FQDN?
      {:error, :einval} -> addr
    end
  end
end

# stun_servers: "addr:port"
# turn_servers: "addr:port:username:password:proto"
config :membrane_videoroom_demo,
  stun_servers:
    System.get_env("STUN_SERVERS", "64.233.163.127:19302") |> ConfigParser.parse_stun_servers(),
  turn_servers: System.get_env("TURN_SERVERS", "") |> ConfigParser.parse_turn_servers(),
  max_display_num: System.get_env("MAX_DISPLAY_NUM", "3") |> ConfigParser.parse_max_display_num(),
  max_participants_num:
    System.get_env("MAX_PARTICIPANTS_NUM") |> ConfigParser.parse_max_participants_num()

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
