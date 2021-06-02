export function createFakeVideoStream({
  width = 1,
  height = 1,
}: {
  width: number;
  height: number;
}): MediaStream {
  const canvas = document.createElement("canvas") as any;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    ctx.fillStyle = "rgba(0,0,0,0)";
    ctx.fillRect(0, 0, width, height);
  }
  return canvas.captureStream(0);
}
