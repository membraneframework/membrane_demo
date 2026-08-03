defmodule Reader do
  defstruct []
end

defimpl Membrane.HLS.Reader, for: Reader do
  @impl true
  def read(_, %URI{path: path}, _), do: File.read(path)

  @impl true
  def exists?(_, %URI{path: path}) do
    case File.stat(path) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end
end
