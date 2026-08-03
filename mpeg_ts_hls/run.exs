{:ok, _supervisor, pipeline_pid} = Membrane.Pipeline.start_link(HLSPipeline, [uri: URI.new!("./fixtures/mpeg-ts/stream.m3u8")])
ref = Process.monitor(pipeline_pid)
:ok = receive do
  {:DOWN, ^ref, :process, ^pipeline_pid, _reason} -> :ok
end
