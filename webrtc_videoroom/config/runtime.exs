import Config

defmodule ConfigParser do
  def parse_external_ip(ip) do
    with {:ok, parsed_ip} <- ip |> to_charlist() |> :inet.parse_address() do
      parsed_ip
    else
      _ ->
        raise("""
        Bad EXTERNAL_IP format. Expected IPv4, got: \
        #{inspect(ip)}
        """)
    end
  end

  def parse_port_range(range) do
    with [str1, str2] <- String.split(range, "-"),
         from when from in 0..65_535 <- String.to_integer(str1),
         to when to in from..65_535 and from <= to <- String.to_integer(str2) do
      {from, to}
    else
      _else ->
        raise("""
        Bad PORT_RANGE enviroment variable value. Expected "from-to", where `from` and `to` \
        are numbers between 0 and 65535 and `from` is not bigger than `to`, got: \
        #{inspect(range)}
        """)
    end
  end
end

config :membrane_videoroom_demo,
  external_ip: System.get_env("EXTERNAL_IP", "127.0.0.1") |> ConfigParser.parse_external_ip(),
  port_range:
    System.get_env("PORT_RANGE", "50000-59999")
    |> ConfigParser.parse_port_range()

config :membrane_videoroom_demo, VideoRoomWeb.Endpoint, [
  {:url, [host: "localhost"]},
  {:http, [otp_app: :membrane_videoroom_demo, port: System.get_env("SERVER_PORT") || 4000]}
]
