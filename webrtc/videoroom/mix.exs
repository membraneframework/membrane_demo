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
      # {:membrane_rtc_engine, "~> 0.1.0"},
      {:membrane_rtc_engine, github: "membraneframework/membrane_rtc_engine", branch: "auto-demand", override: true},
      # {:membrane_webrtc_plugin, "~> 0.2.0"},
      {:membrane_webrtc_plugin, path: "../../../membrane_webrtc_plugin", override: true},
      {:membrane_rtp_plugin, path: "../../../membrane_rtp_plugin", override: true},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.16.0"},
      {:phoenix_live_reload, "~> 1.2"},
      {:poison, "~> 3.1"},
      {:jason, "~> 1.2"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:telemetry, "~> 1.0.0", override: true},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev}
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
