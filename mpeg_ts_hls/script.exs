{:ok, _supervisor, pipeline_pid} = Membrane.Pipeline.start_link(HLSPipeline, [])
ref = Process.monitor(pipeline_pid)
:ok = receive do
  {:DOWN, ^ref, :process, ^pipeline_pid, _reason} -> :ok
end

