defmodule Membrane.SFU.PrivateKey do
  @moduledoc false

  @type key_t() :: String.t()

  @spec is_valid(key :: key_t()) :: boolean()
  def is_valid(key) do
    case UUID.info(key) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end
end
