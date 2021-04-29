interface State {
  isScreenSharingActive: boolean;
  isLocalScreenSharingActive: boolean;
  displayName: string;
  onLocalScreensharingStart?: () => void;
  onLocalScreensharingStop?: () => void;
  onToggleAudio?: () => void;
  onToggleVideo?: () => void;
}

let state: State = {
  displayName: "",
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
  enableAudio: boolean;
  enableVideo: boolean;
}

export function setupRoomUI({
  muteAudio = false,
  muteVideo = false,
  enableAudio,
  enableVideo,
  state: newState,
}: SetupOptions): void {
  state = {
    ...state,
    ...newState,
  };
  updateScreensharingToggleButton(true, "start");
  setupMediaControls(muteAudio, muteVideo, enableAudio, enableVideo);
}

export function setLocalScreenSharingStatus(active: boolean): void {
  state.isLocalScreenSharingActive = active;
}

export function getRoomId(): string {
  return document.getElementById("room")!.dataset.roomId!;
}

function elementId(stream: MediaStream, type: "video" | "audio" | "feed") {
  return `${type}-${stream.id}`;
}

export function addVideoElement(
  stream: MediaStream,
  label: string,
  mute: boolean = false
): void {
  const id = elementId(stream, "video");
  let video = document.getElementById(id) as HTMLVideoElement;

  if (!video) {
    video = setupVideoFeed(stream, label);
  }

  video.id = id;
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = mute;
}

function resizeVideosGrid() {
  const grid = document.getElementById("videos-grid")!;
  grid.className = `grid-${Math.min(2, grid.children.length)}`;
}

function setupVideoFeed(stream: MediaStream, label: string) {
  const copy = (document.querySelector(
    "#video-feed-template"
  ) as HTMLTemplateElement).content.cloneNode(true) as Element;
  const feed = copy.querySelector("div[class='VideoFeed']") as HTMLDivElement;
  const video = feed.querySelector("video") as HTMLVideoElement;
  const videoLabel = feed.querySelector(
    "div[class='VideoLabel']"
  ) as HTMLDivElement;

  feed.id = elementId(stream, "feed");
  videoLabel.innerText = label;

  const grid = document.querySelector("#videos-grid")!;
  grid.appendChild(feed);
  resizeVideosGrid();

  return video;
}

export function addAudioElement(stream: MediaStream): void {
  const id = elementId(stream, "audio");
  let audio = document.getElementById(id) as HTMLAudioElement;

  if (!audio) {
    audio = document.createElement("audio");
  }

  audio.id = id;
  audio.srcObject = stream;
  audio.autoplay = true;
}

export function removeVideoElement(stream: MediaStream): void {
  if (stream.getTracks().length > 0) {
    return;
  }

  document.getElementById(elementId(stream, "feed"))?.remove();
  resizeVideosGrid();
}

export function removeAudioElement(stream: MediaStream): void {
  if (stream.getTracks().length > 0) {
    return;
  }

  document.getElementById(elementId(stream, "audio"))?.remove();
}

export function setScreensharing(
  stream: MediaStream,
  label: string,
  selfLabel: string
): void {
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
  screensharing.style.display = "flex";

  const videoLabel = screensharing.querySelector(
    "div[class='VideoLabel']"
  )! as HTMLDivElement;

  videoLabel.innerText = label.includes(state.displayName) ? selfLabel : label;

  const video = screensharing.querySelector("video")!;
  video.id = stream.id;
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;

  document
    .getElementById("videochat")!
    .classList.add("VideoChat-screensharing");
}

export function removeScreensharing(): void {
  const screensharing = document.getElementById(
    "screensharing"
  )! as HTMLDivElement;
  screensharing.style.display = "none";

  const video = screensharing.querySelector("video")!;
  video.srcObject = null;

  state.isScreenSharingActive = false;

  updateScreensharingToggleButton(true, "start");
  document
    .querySelector("#videochat")!
    .classList.remove("VideoChat-screensharing");
}

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
): void {
  const errorContainer = document.getElementById("videochat-error");
  if (errorContainer) {
    errorContainer.innerHTML = message;
    errorContainer.style.display = "block";
  }
}

export function replaceStream(
  oldStream: MediaStream,
  newStream: MediaStream,
  newLabel: string
): void {
  removeVideoElement(oldStream);
  addVideoElement(newStream, newLabel);
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

function setupMediaControls(
  muteAudio: boolean,
  muteVideo: boolean,
  enableAudio: boolean,
  enableVideo: boolean
) {
  const muteAudioEl = document.getElementById("mic-on")! as HTMLDivElement;
  const unmuteAudioEl = document.getElementById("mic-off")! as HTMLDivElement;

  if (!enableAudio) {
    muteAudioEl.classList.add("DisabledControlIcon");
    unmuteAudioEl.classList.add("DisabledControlIcon");
  }

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

  if (!enableVideo) {
    muteVideoEl.classList.add("DisabledControlIcon");
    unmuteVideoEl.classList.add("DisabledControlIcon");
  }

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
