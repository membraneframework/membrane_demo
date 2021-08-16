alias Membrane.Demo.AudioPipeline
alias Membrane.Demo.VideoPipeline

# mix audio to .aac file
{:ok, pid} = AudioPipeline.start_link({"sound_500f.wav", "sound_1000f.wav"})
AudioPipeline.play(pid)

# merge video to .h264 file
{:ok, pid} = VideoPipeline.start_link({"video_red.h264", "video_green.h264"})
VideoPipeline.play(pid)
