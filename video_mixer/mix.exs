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
      {:membrane_core, "~> 0.7.0"},
      {:membrane_file_plugin, "~> 0.6.0"},
      {:membrane_video_merger_plugin, "~> 0.1.0"},
      {:membrane_wav_plugin, "~> 0.1.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.10.0"},
      {:membrane_aac_fdk_plugin, "~> 0.6.1"},
      {:membrane_audio_mixer_plugin, "~> 0.1.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
