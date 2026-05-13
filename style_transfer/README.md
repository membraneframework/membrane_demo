# Style Transfer

Livebook demo of [`Membrane.StyleTransfer`](https://github.com/membraneframework-labs/membrane_style_transfer_plugin), a Membrane filter that applies neural-network style transfer to raw video frames in real time.

Open `style_transfer.livemd` in Livebook. It contains two pipelines: one with a fixed style and one that swaps styles every 1.5 s. The styled camera feed is rendered in a video tile inside the notebook via WebRTC; the JS + HTML for the tile live in `assets/`.
