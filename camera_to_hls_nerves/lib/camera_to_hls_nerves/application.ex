defmodule CameraToHlsNerves.Application do
  use Application

  def start(_type, _args) do
    File.rm_rf!("/data/output")
    File.mkdir!("/data/output")
    File.cd!("/")

    children = [
      %{id: :hls_server, start: {:inets, :start, [:httpd, httpd_options(), :stand_alone]}},
      CameraToHlsNerves.Pipeline
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
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
