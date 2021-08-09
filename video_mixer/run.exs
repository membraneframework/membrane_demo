# alias Membrane.Demo.VideoMixer
# {:ok, pid} = VideoMixer.start_link({"test_audio.wav", "test_audio.wav"})
# VideoMixer.play(pid)

alias Membrane.Demo.VideoOnly
{:ok, pid} = VideoOnly.start_link({"test_video2.h264", "test_video2.h264"})
VideoOnly.play(pid)
