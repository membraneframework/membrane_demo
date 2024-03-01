{:ok, _supervisor, pipeline_pid} =
  Membrane.Pipeline.start_link(Videoroom.FlvPipeline, [
    %{video: "video.msr", audio: "audio.msr"},
    "output.flv"
  ])

monitor_ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^monitor_ref, :process, _pipeline_pid, _reason} ->
    :ok
end
