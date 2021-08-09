# alias Membrane.Demo.VideoMixer
# {:ok, pid} = VideoMixer.start_link({"test_audio.wav", "test_audio.wav"})
# VideoMixer.play(pid)

alias Membrane.Demo.VideoOnly
{:ok, pid} = VideoOnly.start_link({"test_video.h264", "test_video.h264"})
VideoOnly.play(pid)
