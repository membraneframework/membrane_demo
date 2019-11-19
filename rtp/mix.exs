defmodule Membrane.Demo.RTP.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_demo_rtp,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Membrane.Demo.RTP, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:membrane_core, [env: :prod, path: "~/membrane-core", override: true]},
      {:membrane_bin_rtp, "0.1.0"},
      {:membrane_element_udp, "~> 0.3.0"},
      {:membrane_element_ffmpeg_h264, "~> 0.2.0"},
      {:membrane_element_rtp_h264, "~> 0.2.0"},
      {:membrane_element_sdl, "~> 0.3.0"},
      {:membrane_element_portaudio, "~> 0.3.0"}
    ]
  end
end
