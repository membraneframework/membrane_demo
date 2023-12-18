defmodule CameraToHlsNerves.Application do
  use Application

  def start(_type, _args) do
    File.rm_rf!("/data/output")
    File.mkdir!("/data/output")
    File.cd!("/")

    children = [
      CameraToHlsNerves.Pipeline
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: CameraToHlsNervesSupervisor)
  end

end
