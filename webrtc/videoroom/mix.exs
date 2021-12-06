defmodule VideoRoom.MixProject do
  use Mix.Project

  def project do
    [
      app: :membrane_videoroom_demo,
      version: "0.1.0",
      elixir: "~> 1.12",
      aliases: aliases(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {VideoRoom.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:membrane_core, github: "membraneframework/membrane_core", override: true},
      {:esbuild, "~> 0.1", runtime: Mix.env() == :dev},
      {:membrane_rtc_engine,
       github: "membraneframework/membrane_rtc_engine", branch: "modular_rtc_engine"},
      {:membrane_webrtc_plugin,
       github: "membraneframework/membrane_webrtc_plugin",
       branch: "modular_rtc_engine",
       override: true},
      {:membrane_http_adaptive_stream_plugin,
       github: "membraneframework/membrane_http_adaptive_stream_plugin"},
      {:membrane_mp4_plugin, "~> 0.9.0", override: true},
      {:membrane_aac_plugin, "~> 0.8.0"},
      {:membrane_aac_format, "~> 0.3.0", override: true},
      {:membrane_aac_fdk_plugin, "~> 0.8.0"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.16.0"},
      {:phoenix_live_reload, "~> 1.2"},
      {:poison, "~> 3.1"},
      {:jason, "~> 1.2"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:uuid, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "cmd --cd assets npm ci"],
      "assets.deploy": [
        "cmd --cd assets npm run deploy",
        "esbuild default --minify",
        "phx.digest"
      ]
    ]
  end
end
