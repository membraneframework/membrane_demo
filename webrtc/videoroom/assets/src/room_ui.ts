interface State {
  onToggleAudio?: () => void;
  onToggleVideo?: () => void;
}

let state: State = {
  onToggleAudio: undefined,
  onToggleVideo: undefined,
};

export function setupRoomUI(setupState: State) {
  state = { ...setupState };
}

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

export function setErrorMessage(
  message: string = "Cannot connect to server, refresh the page and try again"
) {
  const errorContainer = document.getElementById("videochat-error");
  if (errorContainer) {
    errorContainer.innerHTML = message;
  }
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

export function setupMediaControls(muteAudio: boolean, muteVideo: boolean) {
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
