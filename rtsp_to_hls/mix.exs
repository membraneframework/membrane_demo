defmodule Membrane.Demo.RtspToHls.MixProject do
  use Mix.Project

  def project do
    [
      app: :hls_proxy_api,
      version: "0.1.0",
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Membrane.Demo.RtspToHls.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 0.10"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:connection, "~> 1.1"},
      {:membrane_rtsp, "~> 0.3"},
      {:membrane_udp_plugin, "~> 0.8"},
      {:membrane_rtp_plugin, "~> 0.14"},
      {:membrane_rtp_h264_plugin, "~> 0.13"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.8"},
#      {:membrane_h264_ffmpeg_plugin, "~> 0.21"}
#      {:membrane_h264_plugin, "~> 0.1"},
#      {:membrane_h264_format, "~> 0.5"},
      {:membrane_h264_plugin, git: "https://github.com/membraneframework/membrane_h264_plugin.git", branch: "refine_input_stream_format"},
    ]
  end

  defp dialyzer() do
    [
      flags: [:error_handling]
    ]
  end
end
