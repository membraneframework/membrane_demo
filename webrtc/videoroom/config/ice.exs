import Config

# please refer to `ExLibnice.stun_server()` and `ExLibnice.relay_info()` for servers' format
config :membrane_videoroom_demo,
  stun_servers: [%{server_addr: "stun1.l.google.com", server_port: 19_302}],
  turn_servers: []
