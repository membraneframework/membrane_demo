defmodule Membrane.Demo.RTP.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :membrane_demo_rtp,
      version: @version,
      elixir: "~> 1.7",
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
      {:membrane_core,
       github: "membraneframework/membrane_core", branch: "fix/playback", override: true},
      {:membrane_rtp_plugin, github: "membraneframework/membrane_rtp_plugin", branch: :sending},
      # {:membrane_element_udp, "~> 0.3.0"},
      {:membrane_element_udp, github: "membraneframework/membrane-element-udp", branch: :caps},
      {:membrane_h264_ffmpeg_plugin, "~> 0.5.0"},
      {:membrane_rtp_h264_plugin,
       github: "membraneframework/membrane_rtp_h264_plugin", branch: :develop},
      # {:membrane_rtp_h264_plugin,
      #  github: "membraneframework/membrane_rtp_h264_plugin", branch: :develop},
      {:membrane_opus_plugin, github: "membraneframework/membrane_opus_plugin", branch: :parser},
      # {:membrane_rtp_opus_plugin, github: "membraneframework/membrane_rtp_opus_plugin"},
      {:membrane_rtp_opus_plugin,
       github: "membraneframework/membrane_rtp_opus_plugin", branch: :payloader},
      {:membrane_sdl_plugin, "~> 0.4.0"},
      {:membrane_portaudio_plugin, github: "membraneframework/membrane_portaudio_plugin"},
      {:membrane_element_hackney, "~> 0.3.0"},
      {:membrane_realtimer_plugin,
       github: "membraneframework/membrane_realtimer_plugin", branch: :develop},
      {:libsrtp, github: "membraneframework/elixir_libsrtp", branch: "develop"}
    ]
  end
end
