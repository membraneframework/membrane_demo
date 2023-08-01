alias Membrane.Demo.AudioPipeline
alias Membrane.Demo.VideoPipeline

# mix audio to .aac file
{:ok, _supervisor, pid} = AudioPipeline.start_link({"sound_500f.wav", "sound_1000f.wav"})

# merge video to .h264 file
{:ok, _supervisor, pid} = VideoPipeline.start_link({"video_red.h264", "video_green.h264"})
