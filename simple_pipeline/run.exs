{:ok, _sup, pid} = Membrane.Demo.SimplePipeline.start("sample.mp3")
ref = Process.monitor(pid)
receive do
  {:DOWN, ^ref, :process, _pid, _reason} -> :ok
end

