defmodule Membrane.Demo.RtpToHls do
  def play(port \\ 5000) do
    {:ok, pid} = __MODULE__.Pipeline.start_link(port)
    :ok = __MODULE__.Pipeline.play(pid)
    pid
  end
end
