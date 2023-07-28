defmodule Example.Auth do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :example_auth,
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {Example.Auth.Application, []},
      extra_applications: [:membrane_webrtc_server]
    ]
  end

  defp aliases do
    [
      start: "run --no-halt"
    ]
  end

  defp deps do
    [
      {:argon2_elixir, "~> 3.0"},
      {:guardian, "~> 2.2"},
      {:ecto_sql, "~> 3.8"},
      {:postgrex, ">= 0.0.0"},
      {:membrane_webrtc_server, "~> 0.1.3"},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:credo, "~> 1.1.0", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.13"},
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
