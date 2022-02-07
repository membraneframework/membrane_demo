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
      # {:membrane_core, "~> 0.8.1", override: true},
      # {:membrane_core, github: "membraneframework/membrane_core", override: true},
      {:membrane_core,
       github: "membraneframework/membrane_core", branch: "no-linking-timeout", override: true},
      {:membrane_rtc_engine,
       github: "membraneframework/membrane_rtc_engine", branch: "candidate-port-registry"},
      {:membrane_webrtc_plugin,
       github: "membraneframework/membrane_webrtc_plugin",
       branch: "sandbox-debug",
       override: true},
      {:membrane_ice_plugin,
       github: "membraneframework/membrane_turn_plugin", branch: "sandbox-debug", override: true},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.16.0"},
      {:phoenix_live_reload, "~> 1.2"},
      {:jason, "~> 1.2"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},

      # Otel
      {:opentelemetry, "~> 0.6.0", override: true},
      {:opentelemetry_api, "~> 0.6.0", override: true},
      {:opentelemetry_exporter, "~> 0.6.0"},
      {:opentelemetry_zipkin, "~> 0.4.0"},

      # Benchmarks
      {:beamchmark, "~> 0.1.0", only: :benchmark},
      {:stampede, github: "geometerio/stampede-elixir", only: :benchmark},
      {:httpoison, "~> 1.8", only: :benchmark},
      {:poison, "~> 5.0.0", only: :benchmark}
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
