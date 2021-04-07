interface State {
  isScreenSharingActive: boolean;
  isLocalScreenSharingActive: boolean;
  onLocalScreensharingStart?: () => void;
  onLocalScreensharingStop?: () => void;
  onToggleAudio?: () => void;
  onToggleVideo?: () => void;
}
let state: State = {
  isScreenSharingActive: false,
  isLocalScreenSharingActive: false,
  onLocalScreensharingStart: undefined,
  onLocalScreensharingStop: undefined,
  onToggleAudio: undefined,
  onToggleVideo: undefined,
};

interface SetupOptions {
  state?: State;
  muteAudio?: boolean;
  muteVideo?: boolean;
}

export function setupRoomUI({
  muteAudio = false,
  muteVideo = false,
  state: newState,
}: SetupOptions) {
  state = {
    ...state,
    ...newState,
  };
  updateScreensharingToggleButton(true, "start");
  setupMediaControls(muteAudio, muteVideo);
}

export function setLocalScreenSharingStatus(active: boolean) {
  state.isLocalScreenSharingActive = active;
}

export function getRoomId(): string {
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
    const grid = document.getElementById("videos-grid")!;
    grid.appendChild(video);

    grid.className = `grid-${Math.min(2, grid.childNodes.length)}`;
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

  const grid = document.getElementById("videos-grid")!;
  grid.className = `grid-${Math.min(2, grid.childNodes.length)}`;
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
  screensharing.style.display = "flex";

  const video = document.createElement("video");
  video.id = stream.id;
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;
  screensharing.append(video);

  document
    .getElementById("videochat")!
    .classList.add("VideoChat-screensharing");
}

export function removeScreensharing() {
  const screensharing = document.getElementById(
    "screensharing"
  )! as HTMLDivElement;
  screensharing.innerHTML = "";
  screensharing.style.display = "none";

  state.isScreenSharingActive = false;

  updateScreensharingToggleButton(true, "start");
  document
    .getElementById("videochat")!
    .classList.remove("VideoChat-screensharing");
}

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
) {
  const errorContainer = document.getElementById("videochat-error");
  if (errorContainer) {
    errorContainer.innerHTML = message;
    errorContainer.style.display = "block";
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

export function toggleControl(control: "mic" | "video") {
  const mute = document.getElementById(`${control}-on`)! as HTMLDivElement;
  const unmute = document.getElementById(`${control}-off`)! as HTMLDivElement;

  if (mute.style.display === "none") {
    mute.style.display = "block";
    unmute.style.display = "none";
  } else {
    mute.style.display = "none";
    unmute.style.display = "block";
  }
}

function setupMediaControls(muteAudio: boolean, muteVideo: boolean) {
  const muteAudioEl = document.getElementById("mic-on")! as HTMLDivElement;
  const unmuteAudioEl = document.getElementById("mic-off")! as HTMLDivElement;

  const toggleAudio = () => {
    state.onToggleAudio?.();
    toggleControl("mic");
  };
  const toggleVideo = () => {
    state.onToggleVideo?.();
    toggleControl("video");
  };

  muteAudioEl.onclick = toggleAudio;
  unmuteAudioEl.onclick = toggleAudio;

  const muteVideoEl = document.getElementById("video-on")! as HTMLDivElement;
  const unmuteVideoEl = document.getElementById("video-off")! as HTMLDivElement;
  muteVideoEl.onclick = toggleVideo;
  unmuteVideoEl.onclick = toggleVideo;

  if (muteAudio) {
    muteAudioEl.style.display = "none";
    unmuteAudioEl.style.display = "block";
  } else {
    muteAudioEl.style.display = "block";
    unmuteAudioEl.style.display = "none";
  }

  if (muteVideo) {
    muteVideoEl.style.display = "none";
    unmuteVideoEl.style.display = "block";
  } else {
    muteVideoEl.style.display = "block";
    unmuteVideoEl.style.display = "none";
  }
}
