defmodule Example.Auth.UserManager.User do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  @derive {Jason.Encoder, only: [:password, :username]}

  schema "users" do
    field(:password, :string)
    field(:username, :string)

    timestamps()
  end

  def changeset(%__MODULE__{} = user, attrs) do
    user
    |> cast(attrs, [:username, :password])
    |> validate_required([:username, :password])
    |> put_password_hash()
  end

  defp put_password_hash(
         %Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset
       ) do
    change(changeset, password: Argon2.hash_pwd_salt(password))
  end

  defp put_password_hash(changeset), do: changeset
end
