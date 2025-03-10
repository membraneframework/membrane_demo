defmodule MembranePhoenix.Repo do
  use Ecto.Repo,
    otp_app: :membrane_phoenix,
    adapter: Ecto.Adapters.Postgres
end
