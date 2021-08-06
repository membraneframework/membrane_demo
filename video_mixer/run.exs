alias Membrane.Demo.VideoMixer
{:ok, pid} = VideoMixer.start_link({"test_audio.wav", "test_audio.wav"})
VideoMixer.play(pid)
