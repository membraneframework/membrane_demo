defmodule Example.Auth.Repo do
  use Ecto.Repo,
    otp_app: :example_auth,
    adapter: Ecto.Adapters.Postgres
end
