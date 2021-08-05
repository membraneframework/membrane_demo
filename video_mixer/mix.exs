defmodule VideoMixer.MixProject do
  use Mix.Project

  def project do
    [
      app: :video_mixer,
      version: "0.1.0",
      elixir: "~> 1.12",
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
      {:membrane_portaudio_plugin, "~> 0.7.0"},
      {:membrane_ffmpeg_swresample_plugin, "~> 0.7.1"},
      {:membrane_mp3_mad_plugin, "~> 0.7.0"},
      {:membrane_video_merger_plugin, "~> 0.1.0"},
      {:membrane_wav_plugin, "~> 0.1.0"},
      {:membrane_mp4_plugin, "~> 0.6.0"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.10.0"},
      {:membrane_aac_fdk_plugin, "~> 0.6.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
