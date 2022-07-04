defmodule HlsProxyApi.Streams.Stream do
  @moduledoc false

  defstruct [:id, :token, :stream_url]

  @type t :: %__MODULE__{}
end
