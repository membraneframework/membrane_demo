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
      {:membrane_core, "~> 1.0"},
      {:membrane_udp_plugin, "~> 0.12.0"},
      {:membrane_file_plugin, "~> 0.16.0"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.18.0"},
      {:membrane_aac_format, "~> 0.8.0"},
      {:membrane_mp4_plugin, "~> 0.31.0"},
      {:membrane_rtp_aac_plugin, "~> 0.8.0"},
      {:membrane_rtp_plugin, "~> 0.24.0"},
      {:membrane_rtp_h264_plugin, "~> 0.19.0"},
      {:membrane_tee_plugin, "~> 0.12.0"},
      {:membrane_fake_plugin, "~> 0.11.0"},
      {:membrane_aac_plugin, "~> 0.18.0"},
      {:membrane_rtp_format, "~> 0.8.0"},
      {:membrane_h264_plugin, "~> 0.9.0"},
      {:ex_libsrtp, "~> 0.6.0"}
    ]
  end
end
