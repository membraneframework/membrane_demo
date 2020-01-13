defmodule Example.Auth.UserManager.Guardian do
  @moduledoc false

  use Guardian, otp_app: :example_auth
  alias Example.Auth.UserManager

  def subject_for_token(user, _claims) do
    {:ok, to_string(user.id)}
  end

  def resource_from_claims(%{"sub" => id}) do
    case UserManager.get_user(id) do
      nil ->
        {:error, :resource_not_found}

      user ->
        {:ok, user}
    end
  end
end
