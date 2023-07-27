defmodule Membrane.Demo.VideoMixer.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane-demo"

  def project do
    [
      app: :membrane_demo_video_mixer,
      version: @version,
      elixir: "~> 1.12",
      name: "Membrane Demo Video Mixer",
      description: "Membrane simple pipeline demo",
      homepage_url: "https://membraneframework.org",
      source_url: @github_url,
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
      {:membrane_core, "~> 0.12.7"},
      {:membrane_file_plugin, "~> 0.14.0"},
      {:membrane_video_merger_plugin, "~> 0.8.0"},
      {:membrane_wav_plugin, "~> 0.9.1"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.27.0"},
      {:membrane_aac_fdk_plugin, "~> 0.15.1"},
      {:membrane_audio_mix_plugin, "~> 0.15.2"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
