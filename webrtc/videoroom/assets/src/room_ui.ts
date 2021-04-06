import { MembraneWebRTC } from "./membraneWebRTC";

interface State {
  isScreenSharingActive: boolean;
  isLocalScreenSharingActive: boolean;
  onLocalScreensharingStart?: () => void;
  onLocalScreensharingStop?: () => void;
}

let state: State = {
  isScreenSharingActive: false,
  isLocalScreenSharingActive: false,
  onLocalScreensharingStart: undefined,
};

interface Setup {
  onLocalScreensharingStart?: () => void;
  onLocalScreensharingStop?: () => void;
}

export function setupRoomUI(setup: Setup) {
  state = {
    ...setup,
    isScreenSharingActive: false,
    isLocalScreenSharingActive: false,
  };
  updateScreensharingToggleButton(true, "start");
}

export function setLocalScreenSharingStatus(active: boolean) {
  state.isLocalScreenSharingActive = active;
}

export function getRoomId(): String {
  return document.getElementById("room")!.dataset.roomId!;
}

export function addVideoElement(
  _: MediaStreamTrack,
  stream: MediaStream,
  mute: boolean = false
) {
  let video = document.getElementById(stream.id) as HTMLVideoElement;

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
  if (state.isScreenSharingActive) {
    console.error(
      "Cannot set screensharing as either local or remote screensharing is active"
    );
    return;
  }
  state.isScreenSharingActive = true;

  const isLocal = state.isLocalScreenSharingActive;

  updateScreensharingToggleButton(isLocal, isLocal ? "stop" : "start");

  // get screensharing element and clear its content if it has
  // any leftovers
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

  state.isScreenSharingActive = false;

  updateScreensharingToggleButton(true, "start");
}

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
) {
  const errorContainer = document.getElementById("videochat-error");
  if (errorContainer) {
    errorContainer.innerHTML = message;
  }
}

function updateScreensharingToggleButton(
  visible: boolean,
  label: "start" | "stop"
) {
  const toggleButton = document.getElementById(
    "toggle-screensharing"
  )! as HTMLButtonElement;

  if (label === "start") {
    toggleButton.onclick = () => state.onLocalScreensharingStart?.();
  } else {
    toggleButton.onclick = () => state.onLocalScreensharingStop?.();
  }

  toggleButton.innerText =
    label === "start" ? "Start screensharing" : "Stop screensharing";
  toggleButton.style.display = visible ? "block" : "none";
}
