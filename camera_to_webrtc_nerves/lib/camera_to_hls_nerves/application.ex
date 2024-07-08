defmodule CameraToHlsNerves.Application do
  require Logger
  use Application

  @port 8829

  def start(_type, _args) do
    File.cd!("/")

    children = [
      {CameraToHlsNerves.Pipeline, @port},
      %{
        id: :server,
        start: {:inets, :start, [:httpd, httpd_options(), :stand_alone]}
      }
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CameraToHlsNervesSupervisor)
  end

  defp httpd_options() do
    [
      bind_address: ~c"0.0.0.0",
      port: 8000,
      document_root: ~c".",
      server_name: ~c"camera_to_webrtc_nerves",
      server_root: ~c"/"
    ]
  end
end
