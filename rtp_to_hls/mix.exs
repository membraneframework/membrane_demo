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
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 0.5.1", override: true},
      {:membrane_element_udp, "~> 0.3.2"},
      {:membrane_element_file, "~> 0.3.0"},
      {:membrane_bin_rtp, "0.1.2"},
      {:membrane_element_ffmpeg_h264,
       git: "git@github.com:membraneframework/membrane-element-ffmpeg-h264.git"},
      {:membrane_http_adaptive_stream_plugin,
       git: "git@github.com:membraneframework/membrane-element-http-adaptive-stream.git", override: true},
       {:membrane_aac_format, "~> 0.1.0"},
      {:membrane_mp4_plugin, git: "git@github.com:membraneframework/membrane-element-mp4.git"},
      {:membrane_element_rtp_aac,
       git: "git@github.com:membraneframework/membrane-element-rtp-aac.git"},
      {:membrane_element_rtp,
       git: "git@github.com:membraneframework/membrane-element-rtp.git",
       branch: "timestamper",
       override: true},
      {:membrane_element_tee, "~> 0.3.2"},
      {:membrane_scissors_plugin,
       git: "git@github.com:membraneframework/membrane-element-scissors.git"},
      {:turbojpeg, git: "git@github.com:membraneframework/elixir-turbojpeg.git"},
      {:membrane_element_fake, "~> 0.3"},
      {:membrane_loggers, "~> 0.3.0"},
      {:membrane_aac_plugin, github: "membraneframework/membrane_aac_plugin"}
    ]
  end
end
