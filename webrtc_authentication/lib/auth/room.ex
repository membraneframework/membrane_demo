defmodule Example.Auth.Room do
  @moduledoc false
  use Membrane.WebRTC.Server.Room

  @impl true
  def on_join(auth_data, state) do
    with {:ok, _claims} <-
           Guardian.decode_and_verify(
             Example.Auth.UserManager.Guardian,
             auth_data.credentials.token
           ) do
      {:ok, state}
    end
  end
end
