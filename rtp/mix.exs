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
      {:membrane_core, "~> 0.10"},
      {:membrane_rtp_plugin, "~> 0.14"},
      {:membrane_udp_plugin, "~> 0.8"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.21"},
      {:membrane_rtp_h264_plugin, "~> 0.13"},
      {:membrane_opus_plugin, "~> 0.15"},
      {:membrane_rtp_opus_plugin, "~> 0.6"},
      {:membrane_sdl_plugin, "~> 0.14"},
      {:membrane_portaudio_plugin, "~> 0.13"},
      {:membrane_file_plugin, "~> 0.12.0"},
      {:ex_libsrtp, "~> 0.4"},
      {:membrane_realtimer_plugin, "~> 0.5"}
    ]
  end
end
