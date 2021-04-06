export const MEDIA_CONSTRAINTS: MediaStreamConstraints = {
  audio: true,
  video: { width: 1280, height: 720 },
};

export const SCREENSHARING_CONSTRAINTS: MediaStreamConstraints = {
  audio: false,
  video: { width: 1280, height: 720, frameRate: 5 },
};
