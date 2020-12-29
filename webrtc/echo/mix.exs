defmodule Echo.MixProject do
  use Mix.Project

  def project do
    [
      app: :echo,
      version: "0.1.0",
      elixir: "~> 1.10",
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

  defp deps do
    [
      {:membrane_core, "~> 0.6.1", override: true},
      {:membrane_file_plugin, "~> 0.5.0"},
      {:membrane_hackney_plugin, "~> 0.4.0"},
      {:websockex, "~> 0.4.2"},
      {:poison, "~> 3.1"},
      {:membrane_realtimer_plugin,
       github: "membraneframework/membrane_realtimer_plugin", branch: :develop},
      {:membrane_funnel_plugin, "~> 0.1.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.7.0"},
      {:membrane_rtp_h264_plugin, github: "membraneframework/membrane_rtp_h264_plugin"},
      {:ex_sdp, "~> 0.2.0"},
      {:membrane_ice_plugin, github: "membraneframework/membrane_ice_plugin", override: true},
      {:membrane_dtls_plugin, "0.1.0"},
      {:membrane_rtp_plugin, github: "membraneframework/membrane_rtp_plugin"},
      {:membrane_rtp_opus_plugin, "~> 0.2.0"},
      {:membrane_opus_plugin, "~> 0.2.0"}
    ]
  end
end
