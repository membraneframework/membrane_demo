export function addVideoElement(
  _: MediaStreamTrack,
  stream: MediaStream,
  mute: boolean = false
) {
  let video = <HTMLVideoElement>document.getElementById(stream.id);

  if (!video) {
    video = document.createElement("video");
    video.id = stream.id;
    document.getElementById("videochat")?.appendChild(video);
  }
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = mute;
}

export function removeVideoElement(_: MediaStreamTrack, stream: MediaStream) {
  if (stream.getTracks().length > 0) {
    return;
  }

  const video = <HTMLVideoElement>document.getElementById(stream.id);
  if (video) {
    video.remove();
  }
}

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
) {
  const control = document.getElementById("control");
  if (control) {
    control.innerHTML = message;
  }
}

export function setPlayerLinks(prefix: string) {
  const player = document.getElementById("player-link")!;
  player.innerHTML = "";

  const playerUrl = `${window.location.origin}/player/${prefix}`;
  const streamUrl = `${window.location.origin}/video/${prefix}/index.m3u8`;

  const a = document.createElement("a");
  a.href = playerUrl;
  a.target = "_blank";
  a.innerText = "Click here to see your HLS stream";
  player.appendChild(a);

  const span = document.createElement("span");
  span.innerText = `Or paste this URL to your HLS player: ${streamUrl}`;
  player.appendChild(span);
}

export function removePlayerLinks() {
  const player = document.getElementById("player-link")!;
  player.innerHTML = "";
}
