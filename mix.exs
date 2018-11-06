defmodule Membrane.Demo.MixProject do
  use Mix.Project

  @version "0.2.0"
  @github_url "https://github.com/membraneframework/membrane-element-mad"

  def project do
    [
      app: :membrane_demo,
      version: @version,
      elixir: "~> 1.7",
      name: "Membrane Demo",
      description: "Membrane Multimedia Framework (Demo Applications)",
      homepage_url: "https://membraneframework.org",
      source_url: @github_url,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Membrane.Demo.App, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, github: "membraneframework/membrane-core", override: true},
      {:membrane_element_file, github: "membraneframework/membrane-element-file"},
      {:membrane_element_portaudio, github: "membraneframework/membrane-element-portaudio"},
      {:membrane_element_ffmpeg_swresample,
       github: "membraneframework/membrane-element-ffmpeg-swresample"},
      {:membrane_element_mad, github: "membraneframework/membrane-element-mad"},
      {:membrane_caps_audio_raw,
       github: "membraneframework/membrane-caps-audio-raw", override: true},
      {:bunch, github: "membraneframework/bunch", override: true},
      {:membrane_loggers, github: "membraneframework/membrane-loggers"},
      {:membrane_common_c, github: "membraneframework/membrane-common-c", override: true}
    ]
  end
end
