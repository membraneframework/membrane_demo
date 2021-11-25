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
      {:membrane_core,
       github: "membraneframework/membrane_core", branch: "auto-demand", override: true},
      {:membrane_rtc_engine,
       github: "membraneframework/membrane_rtc_engine", branch: "auto-demand"},
      {:membrane_funnel_plugin,
       github: "membraneframework/membrane_funnel_plugin", branch: "auto-demand", override: true},
      {:esbuild, "~> 0.1", runtime: Mix.env() == :dev},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.6"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_view, "~> 0.16.0"},
      {:phoenix_live_reload, "~> 1.2"},
      {:jason, "~> 1.2"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:uuid, "~> 1.1"},
      {:ex_sdp, github: "membraneframework/ex_sdp", override: true},
      {:stampede, github: "geometerio/stampede-elixir"},
      #{:beamchmark, path: "~/Repos/beamchmark"}
      {:beamchmark, github: "membraneframework/beamchmark", branch: :dev}
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
