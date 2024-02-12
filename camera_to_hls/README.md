# Membrane Demo - Camera Video to HLS

This script demonstrates capturing camera video and broadcasting it via HLS.

To run the demo, you need [Elixir installed](https://elixir-lang.org/install.html) on your machine (it's best to use a version manager, like `asdf`). Then, run

```bash
elixir camera_to_hls.exs
```

and when it prints that playback is available, visit `http://localhost:8000/stream.html`. You should see the stream from the camera there. The stream can be also played with players other than the browser, like `vlc` or `ffplay`, for example

```bash
ffplay http://localhost:8000/output/index.m3u8
```

Should there be any errors when compiling the script's dependencies, you may need to install [FFmpeg](https://ffmpeg.org/), which we use to encode the stream from the camera.


You might be asked to grant access to your camera, as some operating systems require that. In case of the absence of a physical camera, it is necessary to use a virtual camera (e.g. OBS, [see how to set up the virtual camera in OBS](https://obsproject.com/kb/virtual-camera-guide)).

For an example of serving HLS within a Phoenix project, see the [rtmp_to_hls demo](../rtmp_to_hls/).

<details>
<summary>
<b>Debugging</b>
</summary>

### Camera not found
If you have a camera but you still receiving the error
```
[video4linux2,v4l2 @ 0x745cf00b0440] Cannot open video device default: No such file or directory
```
The [Membrane CameraCapture Plugin](https://github.com/membraneframework/membrane_camera_capture_plugin) isn't able to find the default camera.
You can find it manually with `v4l2-ctl --list-devices` and then manually set it on the CameraCapture Plugin.
```diff
-       child(:source, Membrane.CameraCapture)
+       child(:source, %Membrane.CameraCapture{device: "/dev/video0"})
```
</details>

## Copyright and License

Copyright 2022, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

[![Software Mansion](https://docs.membrane.stream/static/logo/swm_logo_readme.png)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane)

Licensed under the [Apache License, Version 2.0](LICENSE)
