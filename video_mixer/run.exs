# alias Membrane.Demo.AudioOnly
# {:ok, pid} = AudioOnly.start_link({"test_audio.wav", "test_audio.wav"})
# AudioOnly.play(pid)

alias Membrane.Demo.VideoOnly
{:ok, pid} = VideoOnly.start_link({"red.h264", "green.h264"})
VideoOnly.play(pid)
