defmodule Membrane.Demo.SimpleElement.MixProject do
  use Mix.Project

  @version "0.5.0"
  @github_url "https://github.com/membraneframework/membrane-demo"

  def project do
    [
      app: :membrane_demo_simple_element,
      version: @version,
      elixir: "~> 1.12",
      name: "Membrane Demo Simple Element",
      description: "Membrane simple element demo",
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
      {:membrane_core, "~> 1.0"},
      {:membrane_file_plugin, "~> 0.16.0"},
      {:membrane_portaudio_plugin, "~> 0.18.0"},
      {:membrane_ffmpeg_swresample_plugin, "~> 0.19.0"},
      {:membrane_mp3_mad_plugin, "~> 0.18.0"},
      {:dialyxir, "~> 1.2", only: [:dev], runtime: false}
    ]
  end
end
