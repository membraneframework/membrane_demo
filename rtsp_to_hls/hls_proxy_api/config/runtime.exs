import Config

config :hls_proxy_api, output_dir: System.fetch_env!("OUTPUT_PATH")

config :hls_proxy_api, hls_path: System.fetch_env!("HLS_PATH")
