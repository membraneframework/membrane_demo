# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config
#
config :membrane_core, Membrane.Logger,
  loggers: [
    %{
      module: Membrane.Loggers.Console,
      id: :console,
      level: :info,
      options: [],
      tags: [:all]
    }
  ],
  level: :info
