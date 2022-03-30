defmodule Membrane.Demo.CameraToHls do
  @moduledoc """
  This is an entry moudle for the demo.

  It will start accepting RTP streams for payload types 96, 127 that should
  contain multimedia in the format of H264 and AAC, respectively. Pipeline will
  then transform RTP streams to HLS video and audio
  streams.
  """

  use Application
  alias Membrane.Demo.CameraToHls.Pipeline

  @impl true
  def start(_type, _args) do
    {:ok, pid} = Pipeline.start_link()
    Membrane.Pipeline.play(pid)

    {:ok, pid}
  end
end
