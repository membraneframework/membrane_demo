declare global {
  interface HTMLCanvasElement {
    captureStream: (frames: number) => MediaStream;
  }
}

export default function createFakeStream(): MediaStream {
  const canvas = document.createElement("canvas") as HTMLCanvasElement;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    ctx.fillStyle = "rgba(0,0,0,0)";
    ctx.fillRect(0, 0, 1, 1);
  }
  // return fake stream with framerate 0 so it won't send any media
  return canvas.captureStream(0);
}
