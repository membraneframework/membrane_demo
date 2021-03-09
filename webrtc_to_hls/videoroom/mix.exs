defmodule VideoRoom.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_videoroom_demo,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {VideoRoom.App, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:membrane_core, "~> 0.6.1"},
      {:membrane_core,
       github: "membraneframework/membrane_core", branch: "develop", override: true},
      {:membrane_webrtc_plugin,
       github: "membraneframework/membrane_webrtc_plugin", branch: "endpoint"},
      {:membrane_element_tee, "~> 0.4.1"},
      {:membrane_element_fake, "~> 0.4.0"},
      {:plug_cowboy, "~> 2.0"},
      {:poison, "~> 3.1"},
      {:membrane_file_plugin, "~> 0.5.0"},
      {:membrane_h264_ffmpeg_plugin, [env: :prod, git: "https://github.com/membraneframework/membrane_h264_ffmpeg_plugin.git", branch: "wait-for-keyframe"]},
      {:membrane_http_adaptive_stream_plugin, "~> 0.1.0"},
      {:membrane_mp4_plugin, "~> 0.3.0"},
      {:membrane_opus_plugin, "~> 0.2.1"},
      {:membrane_aac_fdk_plugin, "~> 0.4.0"}
    ]
  end
end
