export function getRoomId(): string {
  return document.getElementById("room")!.dataset.roomId!;
}

// TODO: remove me when testing is done
let localVideoElement: Node;
let localMediaStream: MediaStream;

function cloneLocalVideo() {
  if (!localVideoElement) return;

  console.log("Adding element once again...");

  const grid = document.querySelector("#videos-grid")!;
  const video = localVideoElement.query;
  grid.appendChild(localVideoElement);
  resizeVideosGrid();
}

export function setupDisconnectButton(fun) {
  const disconnectButton = document.getElementById(
    "disconnect"
  )! as HTMLButtonElement;
  disconnectButton.onclick = fun;
}

function elementId(peerId: string, type: "video" | "audio" | "feed") {
  return `${type}-${peerId}`;
}

export function attachStream(stream: MediaStream, peerId: string): void {
  const videoId = elementId(peerId, "video");
  const audioId = elementId(peerId, "audio");

  let video = document.getElementById(videoId) as HTMLVideoElement;
  let audio = document.getElementById(audioId) as HTMLAudioElement;

  // TODO: remove me after testing
  localMediaStream = stream;

  video.srcObject = stream;
  audio.srcObject = stream;
}

export function addVideoElement(
  peerId: string,
  label: string,
  isLocalVideo: boolean
): void {
  const videoId = elementId(peerId, "video");
  const audioId = elementId(peerId, "audio");

  let video = document.getElementById(videoId) as HTMLVideoElement;
  let audio = document.getElementById(audioId) as HTMLAudioElement;

  if (!video && !audio) {
    const values = setupVideoFeed(peerId, label, isLocalVideo);
    video = values.video;
    audio = values.audio;
  }

  video.id = videoId;
  video.autoplay = true;
  video.playsInline = true;
  video.muted = true;

  audio.id = audioId;
  audio.autoplay = true;
  if (isLocalVideo) {
    audio.muted = true;
  }
}

export function setParticipantsList(participants: Array<string>): void {
  const participantsNamesEl = document.getElementById(
    "participants-list"
  ) as HTMLDivElement;
  participantsNamesEl.innerHTML =
    "<b>Participants</b>: " + participants.join(", ");
}

function resizeVideosGrid() {
  const grid = document.getElementById("videos-grid")!;

  const videos = grid.children.length;

  let videosPerRow;

  // break points for grid layout
  if (videos < 2) {
    videosPerRow = 1;
  } else if (videos < 4) {
    videosPerRow = 2;
  } else if (videos < 7) {
    videosPerRow = 3;
  } else {
    videosPerRow = 4;
  }

  let indexFound = -1;
  let classToRemove: string | undefined = undefined;
  for (const [index, value] of grid.classList.entries()) {
    if (value.startsWith("grid-cols")) {
      indexFound = index;
      classToRemove = value;
      break;
    }
  }

  if (indexFound !== -1 && classToRemove) {
    grid.classList.remove(classToRemove);
  }

  grid.classList.add(`grid-cols-${videosPerRow}`);
}

function setupVideoFeed(peerId: string, label: string, isLocalVideo: boolean) {
  const copy = (document.querySelector(
    "#video-feed-template"
  ) as HTMLTemplateElement).content.cloneNode(true) as Element;
  const feed = copy.querySelector("div[name='video-feed']") as HTMLDivElement;
  const audio = feed.querySelector("audio") as HTMLAudioElement;
  const video = feed.querySelector("video") as HTMLVideoElement;
  const videoLabel = feed.querySelector(
    "div[name='video-label']"
  ) as HTMLDivElement;

  feed.id = elementId(peerId, "feed");
  videoLabel.innerText = label;

  if (isLocalVideo) {
    video.classList.add("flip-horizontally");

    localVideoElement = feed.cloneNode(true);

    // @ts-ignore
    window.CLONE = cloneLocalVideo;
  }

  const grid = document.querySelector("#videos-grid")!;
  grid.appendChild(feed);
  resizeVideosGrid();

  return { audio, video };
}

export function removeVideoElement(peerId: string): void {
  document.getElementById(elementId(peerId, "feed"))?.remove();
  resizeVideosGrid();
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
