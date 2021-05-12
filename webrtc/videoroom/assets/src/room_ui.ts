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
}

export function setupRoomUI({
  muteAudio = false,
  muteVideo = false,
  state: newState,
}: SetupOptions): void {
  state = {
    ...state,
    ...newState,
  };
  updateScreensharingToggleButton(true, "start");
  setupMediaControls(muteAudio, muteVideo);
}

export function setLocalScreenSharingStatus(active: boolean): void {
  state.isLocalScreenSharingActive = active;
}

export function getRoomId(): string {
  return document.getElementById("room")!.dataset.roomId!;
}

function elementId(
  streamId: string,
  type: "video" | "audio" | "placeholder" | "feed" | "mutedAudioIcon"
) {
  return `${type}-${streamId}`;
}

export function addVideoElement(
  stream: MediaStream,
  label: string,
  mutedAudio: boolean = false,
  turnedOffVideo: boolean = false,
  showMutedAudioIcon: boolean = false
): void {
  const videoId = elementId(stream.id, "video");
  const audioId = elementId(stream.id, "audio");
  const videoPlaceholderId = elementId(stream.id, "placeholder");
  const mutedAudioIconId = elementId(stream.id, "mutedAudioIcon");

  let video = document.getElementById(videoId) as HTMLVideoElement;
  let audio = document.getElementById(audioId) as HTMLAudioElement;
  let videoPlaceholder = document.getElementById(
    videoPlaceholderId
  ) as HTMLDivElement;
  let mutedAudioIcon = document.getElementById(
    mutedAudioIconId
  ) as HTMLDivElement;

  if (!video && !audio) {
    const values = setupVideoFeed(stream, label);
    video = values.video;
    audio = values.audio;
    videoPlaceholder = values.videoPlaceholder;
    mutedAudioIcon = values.mutedAudioIcon;
  }

  video.id = videoId;
  video.srcObject = stream;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = true;

  audio.id = audioId;
  audio.srcObject = stream;
  audio.autoplay = true;
  audio.muted = mutedAudio;

  videoPlaceholder.id = videoPlaceholderId;
  mutedAudioIcon.id = mutedAudioIconId;

  if (!turnedOffVideo) {
    videoPlaceholder.style.display = "none";
  }
  if (!showMutedAudioIcon) {
    mutedAudioIcon.style.display = "none";
  }
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
  feed.style.display = "none";
  const audio = feed.querySelector("audio") as HTMLAudioElement;
  const video = feed.querySelector("video") as HTMLVideoElement;
  const videoLabel = feed.querySelector(
    "div[class='VideoLabel']"
  ) as HTMLDivElement;
  const videoPlaceholder = feed.querySelector(
    "div[class='VideoPlaceholder']"
  ) as HTMLDivElement;
  const mutedAudioIcon = feed.querySelector(
    "div[class='MutedAudioIcon'"
  ) as HTMLDivElement;

  feed.id = elementId(stream.id, "feed");
  videoLabel.innerText = label;

  const grid = document.querySelector("#videos-grid")!;
  grid.appendChild(feed);
  resizeVideosGrid();

  return { audio, video, videoPlaceholder, mutedAudioIcon };
}

export function toggleVideoPlaceholder(streamId: string): void {
  const placeholder = document.getElementById(
    elementId(streamId, "placeholder")
  );

  if (placeholder) {
    placeholder.style.display =
      placeholder.style.display == "none" ? "flex" : "none";
  }
}

export function toggleMutedAudioIcon(streamId: string): void {
  const mutedAudioIcon = document.getElementById(
    elementId(streamId, "mutedAudioIcon")
  );

  if (mutedAudioIcon) {
    mutedAudioIcon.style.display =
      mutedAudioIcon.style.display == "none" ? "block" : "none";
  }
}

export function removeVideoElement(stream: MediaStream): void {
  if (stream.getTracks().length > 0) {
    return;
  }

  document.getElementById(elementId(stream.id, "feed"))?.remove();
  resizeVideosGrid();
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

export function displayVideoElement(streamId: string): void {
  const feedId = elementId(streamId, "feed");
  document.getElementById(feedId)!.style.display = "block";
}

export function hideVideoElement(streamId: string): void {
  const feedId = elementId(streamId, "feed");
  document.getElementById(feedId)!.style.display = "none";
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
