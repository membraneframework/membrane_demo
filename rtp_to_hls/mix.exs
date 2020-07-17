defmodule Membrane.Demo.RtpToHls.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_demo_rtp_to_hls,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Membrane.Demo.RtpToHls, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 0.5.1"},
      {:membrane_element_udp, "~> 0.3.2"},
      {:membrane_element_file, "~> 0.3.0"},
      {:membrane_element_ffmpeg_h264, "~> 0.3.0"},
       {:membrane_http_adaptive_stream_plugin, "~> 0.1.0"},
      {:membrane_aac_format, "~> 0.1.0"},
      {:membrane_mp4_plugin, "~> 0.3.0"},
      {:membrane_rtp_aac_plugin, "~> 0.1.0-alpha"},
      {:membrane_rtp_plugin, "~> 0.4.0-alpha"},
      {:membrane_rtp_h264_plugin, "~> 0.3.0-alpha"},
      {:membrane_element_tee, "~> 0.3.2"},
      {:membrane_element_fake, "~> 0.3"},
      {:membrane_loggers, "~> 0.3.0"},
      {:membrane_aac_plugin, "~> 0.4.0"}
    ]
  end
end
