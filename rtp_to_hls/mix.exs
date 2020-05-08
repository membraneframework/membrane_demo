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
      {:membrane_element_udp,
       git: "git@github.com:membraneframework/membrane-element-udp.git", branch: "group-packets"},
      {:membrane_element_file, "~> 0.3.0"},
      {:membrane_bin_rtp, "0.1.2"},
      {:membrane_element_ffmpeg_h264,
       git: "git@github.com:membraneframework/membrane-element-ffmpeg-h264.git", branch: "nalu"},
      {:membrane_element_http_adaptive_stream,
       git: "git@github.com:membraneframework/membrane-element-http-adaptive-stream.git"},
      {:membrane_caps_aac,
       git: "git@github.com:membraneframework/membrane-caps-audio-aac.git",
       ref: "f7006036cf769603fa8ae70b8092e0d3bc06546c",
       override: true},
      {:membrane_element_mp4, git: "git@github.com:membraneframework/membrane-element-mp4.git"},
      {:membrane_element_rtp_aac,
       git: "git@github.com:membraneframework/membrane-element-rtp-aac.git"},
      {:membrane_element_rtp,
       git: "git@github.com:membraneframework/membrane-element-rtp.git",
       branch: "timestamper",
       override: true},
      {:membrane_element_tee, "~> 0.3.2"},
      {:membrane_element_scissors,
       git: "git@github.com:membraneframework/membrane-element-scissors.git", ref: "refactor"},
      {:turbojpeg, git: "git@github.com:membraneframework/elixir-turbojpeg.git"},
      {:membrane_element_fake, "~> 0.3"},
      {:membrane_loggers, "~> 0.3.0"}
    ]
  end
end
