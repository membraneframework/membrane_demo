alias Membrane.Demo.AudioPipeline
alias Membrane.Demo.VideoPipeline

# mix audio to .aac file
{:ok, pid} = AudioPipeline.start_link({"500f.wav", "1000f.wav"})
AudioPipeline.play(pid)

# merge video to .h264 file
{:ok, pid} = VideoPipeline.start_link({"red.h264", "green.h264"})
VideoPipeline.play(pid)
