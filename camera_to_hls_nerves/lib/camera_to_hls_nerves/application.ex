defmodule CameraToHlsNerves.Application do
  use Application

  def start(_type, _args) do
    File.rm_rf!("/data/output")
    File.mkdir!("/data/output")

    children = [
      CameraToHlsNerves.HlsServer,
      CameraToHlsNerves.Pipeline
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
