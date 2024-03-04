{:ok, _supervisor, pipeline_pid} =
  Membrane.Pipeline.start_link(Videoroom.FlvPipeline, [
    # %{video: "video.msr", audio: "audio.msr"},
    %{
      video:
        "video_681e22d2-be22-4a1c-87b5-db87b7ca6909_3e9178b0-1e2c-40b0-b0c7-ca11e04f34cc.msr",
      audio: "audio_681e22d2-be22-4a1c-87b5-db87b7ca6909_67adfa59-471b-4fc9-bc1e-a5ed11f10160.msr"
    },
    # "output.flv"
    "output.mkv"
  ])

monitor_ref = Process.monitor(pipeline_pid)

# Wait for the pipeline to finish
receive do
  {:DOWN, ^monitor_ref, :process, _pipeline_pid, _reason} ->
    :ok
end
