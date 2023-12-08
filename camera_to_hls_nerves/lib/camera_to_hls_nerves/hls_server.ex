defmodule CameraToHlsNerves.HlsServer do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: :hls_server)
  end

  @impl true
  def init(_arg) do
    {:ok, %{}}
  end

  @impl true
  def handle_info(:playlist_ready, _state) do
    File.cd!("/")

    :inets.start()

    :inets.start(:httpd, httpd_options())
  end

  defp httpd_options() do
    [
      bind_address: ~c"0.0.0.0",
      port: 8000,
      document_root: ~c".",
      server_name: ~c"camera_to_hls_nerves",
      server_root: ~c"/"
    ]
  end
end
