defmodule WebRTCToHLS.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_webrtc_to_hls_demo,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {WebRTCToHLS.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    [
      {:membrane_core, github: "membraneframework/membrane_core", override: true},
      {:membrane_rtc_engine,
       github: "membraneframework/membrane_rtc_engine", branch: "simulcast"},
      {:membrane_webrtc_plugin,
       github: "membraneframework/membrane_webrtc_plugin", branch: "simulcast", override: true},
      {:membrane_element_tee, "~> 0.5.0"},
      {:membrane_element_fake, "~> 0.5.0"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.3"},
      {:poison, "~> 3.1"},
      {:jason, "~> 1.2"},
      {:membrane_file_plugin, "~> 0.5.0"},
      # HLS_Endpoint deps
      {:membrane_http_adaptive_stream_plugin,
       github: "membraneframework/membrane_http_adaptive_stream_plugin", override: true},
      {:membrane_mp4_plugin, "~> 0.9.0", override: true},
      {:membrane_h264_ffmpeg_plugin, "~> 0.14.0", override: true},
      {:membrane_aac_plugin, "~> 0.8.0", override: true},
      {:membrane_opus_plugin, "~> 0.8.0", override: true},
      {:membrane_aac_format, "~> 0.3.0", override: true},
      {:membrane_aac_fdk_plugin, "~> 0.9.0", override: true}
    ]
  end
end
