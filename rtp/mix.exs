defmodule Membrane.Demo.RTP.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :membrane_demo_rtp,
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 1.0.1"},
      {:membrane_rtp_plugin, "~> 0.27.1"},
      {:membrane_udp_plugin, "~> 0.13.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.31.5"},
      {:membrane_h264_plugin, "~> 0.9.0"}, # update to h26x
      {:membrane_rtp_h264_plugin, "~> 0.19.0"},
      {:membrane_opus_plugin, "~> 0.20.1"},
      {:membrane_rtp_opus_plugin, "~> 0.9.0"},
      {:membrane_sdl_plugin, "~> 0.18.2"},
      {:membrane_portaudio_plugin, "~> 0.19.0"},
      {:membrane_file_plugin, "~> 0.17.0"},
      {:membrane_realtimer_plugin, "~> 0.9.0"},
      {:ex_libsrtp, "~> 0.7.2"}
    ]
  end
end
