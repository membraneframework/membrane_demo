defmodule Example.Simple do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :example_simple,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Example.Simple.Application, []},
      extra_applications: []
    ]
  end

  defp aliases do
    [
      start: "run --no-halt"
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:jason, "~> 1.3"},
      {:membrane_webrtc_server, "~> 0.1.3"},
      {:plug, "~> 1.13"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
