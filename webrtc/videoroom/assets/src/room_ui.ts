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

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
) {
  const errorContainer = document.getElementById("videochat-error");
  if (errorContainer) {
    errorContainer.innerHTML = message;
  }
}

export function setupMuteMicrophoneControls(webrtc: MembraneWebRTC) {
  const muteMicrophoneButton = document.getElementById("mute-microphone")! as HTMLButtonElement;
  muteMicrophoneButton.onclick = () => webrtc.muteMicrophone();
}
