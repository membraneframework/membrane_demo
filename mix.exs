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
      extra_applications: [:logger],
      mod: {MembraneMP3Demo.App, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, path: "../membrane-core", override: true},
      {:membrane_element_file, github: "membraneframework/membrane-element-file"},
      {:membrane_element_portaudio, path: "../membrane-element-portaudio"},
      {:membrane_element_ffmpeg_swresample, path: "../membrane-element-ffmpeg-swresample"},
      {:membrane_element_mad, path: "../membrane-element-mad"},
      {:membrane_caps_audio_raw, path: "../membrane-caps-audio-raw", override: true},
      {:bunch, github: "membraneframework/bunch", override: true},
      {:membrane_loggers, path: "../membrane-loggers"},
      {:membrane_common_c, path: "../membrane-common-c", override: true}
    ]
  end
end
