defmodule Membrane.Demo.SimplePipeline.MixProject do
  use Mix.Project

  @version "0.5.0"
  @github_url "https://github.com/membraneframework/membrane-demo"

  def project do
    [
      app: :membrane_demo_simple_pipeline,
      version: @version,
      elixir: "~> 1.12",
      name: "Membrane Demo Simple Pipeline",
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
      {:membrane_core, "~> 0.10"},
      {:membrane_file_plugin, "~> 0.12"},
      {:membrane_portaudio_plugin, "~> 0.13"},
      {:membrane_ffmpeg_swresample_plugin, "~> 0.15"},
      {:membrane_mp3_mad_plugin, "~> 0.13.0"},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false}
    ]
  end
end
