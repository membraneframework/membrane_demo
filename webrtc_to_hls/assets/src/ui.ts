export function setPreview(stream: MediaStream) {
  let video = <HTMLVideoElement | null>document.getElementById(stream.id);
  if (video) return;

  video = document.createElement("video");
  video.id = stream.id;

  document.getElementById("preview")!.appendChild(video);
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = true;
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

export function setPlayerInfo(streamId: string) {
  const player = <HTMLDivElement>document.getElementById("player-info");

  player.innerHTML = "";

  const playerLink = document.createElement("a");
  playerLink.href = `${window.location.origin}/player/${streamId}`;
  playerLink.target = "_blank";
  playerLink.innerText = "Click here to see your HLS stream";
  player.appendChild(playerLink);

  const streamInfo = document.createElement("span");
  streamInfo.innerText =
    "If you want to use any external player (a lot of them can break due to poor support for stream discontinuities) you can use the URL below.";
  const streamUrl = document.createElement("span");
  streamUrl.innerText = `${window.location.origin}/video/${streamId}/index.m3u8`;

  player.appendChild(streamInfo);
  player.appendChild(streamUrl);
}
