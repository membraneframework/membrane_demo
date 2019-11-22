defmodule Membrane.Demo.Basic.MixProject do
  use Mix.Project

  @version "0.5.0"
  @github_url "https://github.com/membraneframework/membrane-demo"

  def project do
    [
      app: :membrane_demo_basic,
      version: @version,
      elixir: "~> 1.7",
      name: "Membrane Demo",
      description: "Membrane Multimedia Framework (Basic Demo Applications)",
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
      {:membrane_core, "~> 0.5.0"},
      {:membrane_element_file, "~> 0.3.0"},
      {:membrane_element_portaudio, "~> 0.3.1"},
      {:membrane_element_ffmpeg_swresample, "~> 0.3.0"},
      {:membrane_element_mad, "~> 0.3.0"},
      {:membrane_loggers, "~> 0.3.0"},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end
end
