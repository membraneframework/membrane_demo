defmodule RtmpToAdaptiveHls.MixProject do
  use Mix.Project

  def project do
    [
      app: :rtmp_to_adaptive_hls,
      version: "0.1.0",
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {RtmpToAdaptiveHls.Application, []},
      extra_applications: [:logger, :runtime_tools, :inets]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.6.0"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.16.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.2", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:telemetry, "~> 1.0", override: true},
      {:gettext, "~> 0.18"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},

      ## Membrane deps
      {:membrane_core, "~> 1.0"},
      {:membrane_framerate_converter_plugin, "~> 0.8.2"},
      {:membrane_ffmpeg_swscale_plugin, "~> 0.15.1"},
      {:membrane_h264_ffmpeg_plugin, "~> 0.31.6"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.18.5"},
      {:membrane_rtmp_plugin, github: "lastcanal/membrane_rtmp_plugin", branch: "send_messages_to_client_handler_impl"},
      {:membrane_tee_plugin, "~> 0.12.0"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"]
    ]
  end
end
