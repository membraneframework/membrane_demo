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
      {:membrane_core, "~> 0.9.0", override: true},
      {:membrane_rtc_engine, github: "membraneframework/membrane_rtc_engine"},
      {:membrane_webrtc_plugin,
       github: "membraneframework/membrane_webrtc_plugin", override: true},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.3"},
      {:poison, "~> 3.1"},
      {:jason, "~> 1.2"},
      {:membrane_file_plugin, "~> 0.7.0"},

      # HLS_Endpoint deps
      {:membrane_http_adaptive_stream_plugin, "~> 0.5.0"},
      {:membrane_mp4_plugin, "~> 0.11.0", override: true},
      {:membrane_h264_ffmpeg_plugin, "~> 0.16.0"},
      {:membrane_aac_plugin, "~> 0.11.0"},
      {:membrane_aac_format, "~> 0.6.0"},
      {:membrane_aac_fdk_plugin, "~> 0.9.0"},
      # Untill http_adaptive_stream_plugin new version
      {:membrane_tee_plugin, "~> 0.8.0", override: true}
    ]
  end
end
