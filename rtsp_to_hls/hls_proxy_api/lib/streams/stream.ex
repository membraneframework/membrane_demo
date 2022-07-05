defmodule HlsProxyApi.Streams.Stream do
  @moduledoc false

  defstruct [:path, :stream_url]

  @type t :: %__MODULE__{}
end
