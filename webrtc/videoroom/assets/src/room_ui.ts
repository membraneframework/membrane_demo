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
  audioState: "muted" | "unmuted" | "disabled";
  videoState: "muted" | "unmuted" | "disabled";
}

export function setupRoomUI({
  audioState,
  videoState,
  state: newState,
}: SetupOptions): void {
  state = {
    ...state,
    ...newState,
  };
  updateScreensharingToggleButton(true, "start");
  setupMediaControls(audioState, videoState);
}

export function setLocalScreenSharingStatus(active: boolean): void {
  state.isLocalScreenSharingActive = active;
}

export function getRoomId(): string {
  return document.getElementById("room")!.dataset.roomId!;
}

function elementId(
  peerId: string,
  type: "video" | "audio" | "placeholder" | "feed" | "mutedAudioIcon"
) {
  return `${type}-${peerId}`;
}

export function attachStream(
  stream: MediaStream,
  peerId: string,
  isScreenSharing: boolean = false
): void {
  if (isScreenSharing) {
    const screensharing = document.getElementById(
      "screensharing-video"
    )! as HTMLVideoElement;

    screensharing.srcObject = stream;
    screensharing.autoplay = true;
    screensharing.playsInline = true;
  } else {
    const videoId = elementId(peerId, "video");
    const audioId = elementId(peerId, "audio");

    let video = document.getElementById(videoId) as HTMLVideoElement;
    let audio = document.getElementById(audioId) as HTMLAudioElement;

    video.srcObject = stream;
    audio.srcObject = stream;
  }
}

export function addVideoElement(
  peerId: string,
  label: string,
  isLocalVideo: boolean = false,
  mutedAudio: boolean = false,
  mutedVideo: boolean = false,
  showMutedAudioIcon: boolean = false
): void {
  const videoId = elementId(peerId, "video");
  const audioId = elementId(peerId, "audio");
  const videoPlaceholderId = elementId(peerId, "placeholder");
  const mutedAudioIconId = elementId(peerId, "mutedAudioIcon");

  let video = document.getElementById(videoId) as HTMLVideoElement;
  let audio = document.getElementById(audioId) as HTMLAudioElement;
  let videoPlaceholder = document.getElementById(
    videoPlaceholderId
  ) as HTMLDivElement;
  let mutedAudioIcon = document.getElementById(
    mutedAudioIconId
  ) as HTMLDivElement;

  if (!video && !audio) {
    const values = setupVideoFeed(peerId, label, isLocalVideo);
    video = values.video;
    audio = values.audio;
    videoPlaceholder = values.videoPlaceholder;
    mutedAudioIcon = values.mutedAudioIcon;
  }

  video.id = videoId;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = true;

  audio.id = audioId;
  audio.autoplay = true;
  audio.muted = mutedAudio;

  videoPlaceholder.id = videoPlaceholderId;
  mutedAudioIcon.id = mutedAudioIconId;

  if (!mutedVideo) {
    videoPlaceholder.style.display = "none";
  }
  if (!showMutedAudioIcon) {
    mutedAudioIcon.style.display = "none";
  }
}

export function setParticipantsNamesList(
  participantsNames: Array<string>
): void {
  const participantsNamesEl = document.getElementById(
    "participants-names-list"
  ) as HTMLDivElement;

  participantsNamesEl.innerHTML =
    "<b>Participants</b>: " + participantsNames.join(", ");
}

function resizeVideosGrid() {
  const grid = document.getElementById("videos-grid")!;
  grid.className = `grid-${Math.min(2, grid.children.length)}`;
}

function setupVideoFeed(peerId: string, label: string, isLocalVideo: boolean) {
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

  feed.id = elementId(peerId, "feed");
  videoLabel.innerText = label;

  if (isLocalVideo) {
    video.classList.add("UserOwnVideo");
  }

  const grid = document.querySelector("#videos-grid")!;
  grid.appendChild(feed);
  resizeVideosGrid();

  return { audio, video, videoPlaceholder, mutedAudioIcon };
}

export function toggleVideoPlaceholder(peerId: string): void {
  const placeholder = document.getElementById(elementId(peerId, "placeholder"));

  if (placeholder) {
    placeholder.style.display =
      placeholder.style.display == "none" ? "flex" : "none";
  }
}

export function toggleMutedAudioIcon(peerId: string): void {
  const mutedAudioIcon = document.getElementById(
    elementId(peerId, "mutedAudioIcon")
  );

  if (mutedAudioIcon) {
    mutedAudioIcon.style.display =
      mutedAudioIcon.style.display == "none" ? "block" : "none";
  }
}

export function removeVideoElement(peerId: string): void {
  document.getElementById(elementId(peerId, "feed"))?.remove();
  resizeVideosGrid();
}

export function showScreensharing(label: string, selfLabel: string): void {
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

  videoLabel.innerText =
    `${state.displayName} Screensharing` === label ? selfLabel : label;

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

export function displayVideoElement(peerId: string): void {
  const feedId = elementId(peerId, "feed");
  document.getElementById(feedId)!.style.display = "flex";
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
  audioState: "muted" | "unmuted" | "disabled",
  videoState: "muted" | "unmuted" | "disabled"
) {
  const muteAudioEl = document.getElementById("mic-on")! as HTMLDivElement;
  const unmuteAudioEl = document.getElementById("mic-off")! as HTMLDivElement;

  if (audioState === "disabled") {
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

  if (videoState === "disabled") {
    muteVideoEl.classList.add("DisabledControlIcon");
    unmuteVideoEl.classList.add("DisabledControlIcon");
  }

  muteVideoEl.onclick = toggleVideo;
  unmuteVideoEl.onclick = toggleVideo;

  if (audioState === "unmuted") {
    muteAudioEl.style.display = "block";
    unmuteAudioEl.style.display = "none";
  } else {
    muteAudioEl.style.display = "none";
    unmuteAudioEl.style.display = "block";
  }

  if (videoState === "unmuted") {
    muteVideoEl.style.display = "block";
    unmuteVideoEl.style.display = "none";
  } else {
    muteVideoEl.style.display = "none";
    unmuteVideoEl.style.display = "block";
  }
}
