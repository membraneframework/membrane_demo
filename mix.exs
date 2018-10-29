defmodule MembraneMP3Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_demo,
      version: "0.1.0",
      elixir: "~> 1.5",
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
      {:membrane_core, "~> 0.1"},
      {:membrane_element_file, "~> 0.1"},
      {:membrane_element_portaudio, "~> 0.1"},
      {:membrane_element_ffmpeg_swresample, "~> 0.1"},
      {:membrane_element_mad, "~> 0.1"},
    ]
  end
end
