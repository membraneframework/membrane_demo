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
      mod: {VideoRoom.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      # {:membrane_rtc_engine, github: "membraneframework/membrane_rtc_engine", branch: "turn-servers"},
     {:membrane_rtc_engine, git: "git@github.com:membraneframework/membrane_rtc_engine.git", branch: "turn-api-in-rtc-engine"},
      {:plug_cowboy, "~> 2.0"},
      {:phoenix, "~> 1.5"},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_reload, "~> 1.2"},
      {:poison, "~> 3.1"},
      {:jason, "~> 1.2"},
      {:phoenix_inline_svg, "~> 1.4"},
      {:uuid, "~> 1.1"}
    ]
  end
end
