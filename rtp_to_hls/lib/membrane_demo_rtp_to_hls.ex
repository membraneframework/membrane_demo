defmodule Membrane.Demo.RtpToHls do
  @moduledoc """
  This is an entry moudle for the demo.

  It will start accepting RTP streams for fmt 96, 127 that should
  contain multimedia in the format of H264 and AAC. Pipeline will
  then transform RTP streams to accordingly video and audio HLS
  streams.
  """


  use Application
  alias Membrane.Demo.RtpToHls.Pipeline

  @port 5000

  @impl true
  def start(_type, _args) do
    {:ok, pid} = Pipeline.start_link(@port)
    Membrane.Pipeline.play(pid)

    {:ok, pid}
  end
end
