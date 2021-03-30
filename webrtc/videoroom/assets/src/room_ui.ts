import { MembraneWebRTC } from "./membraneWebRTC";

export function getRoomId(): String {
  return document.getElementById("room")!.dataset.roomId!;
}

export function addVideoElement(
  _: MediaStreamTrack,
  stream: MediaStream,
  mute: boolean = false
) {
  let video = <HTMLVideoElement>document.getElementById(stream.id);

  if (!video) {
    video = document.createElement("video");
    video.id = stream.id;
    document.getElementById("videochat")!.appendChild(video);
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

  document.getElementById(stream.id)?.remove();
}

export function setScreensharing(stream: MediaStream) {
  const startButton = document.getElementById(
    "start-screensharing"
  )! as HTMLButtonElement;
  startButton.style.display = "none";
  const screensharing = document.getElementById(
    "screensharing"
  )! as HTMLDivElement;
  screensharing.innerHTML = "";

  const video = document.createElement("video");
  video.id = stream.id;
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;
  screensharing.append(video);
}

export function removeScreensharing() {
  const screensharing = document.getElementById(
    "screensharing"
  )! as HTMLDivElement;
  screensharing.innerHTML = "";
  const startButton = document.getElementById(
    "start-screensharing"
  )! as HTMLButtonElement;
  startButton.style.display = "block";
}

export function setupScreensharingControls(webrtc: MembraneWebRTC) {
  const startScreensharing = document.getElementById(
    "start-screensharing"
  )! as HTMLButtonElement;
  startScreensharing.onclick = () => webrtc.startScreensharing();
}

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
) {
  const errorContainer = document.getElementById("videochat-error");
  if (errorContainer) {
    errorContainer.innerHTML = message;
  }
}
