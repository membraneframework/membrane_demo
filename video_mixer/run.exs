alias Membrane.Demo.AudioOnly
alias Membrane.Demo.VideoOnly

# mix audio to .aac file
{:ok, pid} = AudioOnly.start_link({"500f.wav", "1000f.wav"})
AudioOnly.play(pid)

# merge video to .h264 file
{:ok, pid} = VideoOnly.start_link({"red.h264", "green.h264"})
VideoOnly.play(pid)
