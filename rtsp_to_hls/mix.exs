defmodule Membrane.Demo.RTSPToHLS.MixProject do
  use Mix.Project

  def project do
    [
      app: :rtsp_to_hls_demo,
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
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(_env), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_core, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:connection, "~> 1.1"},
      {:membrane_http_adaptive_stream_plugin, "~> 0.18.0"},
      {:membrane_realtimer_plugin, "~> 0.9.0"},
      {:membrane_rtsp_plugin,
       github: "membraneframework-labs/membrane_rtsp_plugin",
       branch: "audio-depayloading",
       override: true},
      {:membrane_aac_plugin,
       github: "membraneframework/membrane_aac_plugin", branch: "config-option", override: true},
      {:membrane_rtp_aac_plugin,
       github: "membraneframework/membrane_rtp_aac_plugin",
       branch: "fix-depayloader",
       override: true},
      {:membrane_simple_rtsp_server,
       github: "membraneframework-labs/simple_rtsp_server", branch: "create-server"},
      {:ex_sdp, github: "membraneframework/ex_sdp", branch: "aac-fmtp", override: true},
      {:membrane_mp4_plugin, "~> 0.35.2", override: true},
      {:membrane_udp_plugin, "~> 0.14.0"}
    ]
  end

  defp dialyzer() do
    [
      flags: [:error_handling]
    ]
  end
end
