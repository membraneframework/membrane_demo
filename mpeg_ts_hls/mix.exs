defmodule HlsExample.MixProject do
  use Mix.Project

  def project do
    [
      app: :hls_example,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:membrane_hls_plugin,  github: "kim-company/membrane_hls_plugin"},
      {:membrane_file_plugin, "~> 0.17.0"}
    ]
  end
end
