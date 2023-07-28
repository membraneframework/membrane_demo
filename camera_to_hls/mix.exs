defmodule Membrane.Demo.CameraToHls.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_demo_camera_to_hls,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Membrane.Demo.CameraToHls, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 0.12.7"},
      {:membrane_camera_capture_plugin, "~> 0.5.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.27.0"},
      {:membrane_file_plugin, "~> 0.14.0"},
      {:membrane_ffmpeg_swscale_plugin, "~> 0.12.0"},
      {:membrane_mp4_plugin, "~> 0.24.0"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.15.0"},
      {:membrane_raw_video_format, "~> 0.3.0"}
    ]
  end
end
