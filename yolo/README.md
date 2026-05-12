# YOLO

Livebook demo of [`Membrane.YOLO.Detector`](https://github.com/membraneframework/membrane_yolo_plugin) — a Membrane filter that runs YOLO object detection on raw video frames via ONNX (Ortex), paired with `Membrane.YOLO.Drawer` to overlay bounding boxes.

Open `yolo.livemd` in Livebook. It contains three pipelines: live detection on the system camera, real-time detection on an MP4 pulled from the web, and offline detection that writes a finished MP4 to disk. The live previews are rendered in a video tile inside the notebook via WebRTC; the JS + HTML for the tile live in `assets/`.
