export const AUDIO_MEDIA_CONSTRAINTS: MediaStreamConstraints = {
  audio: true,
  video: false,
};

export const VIDEO_MEDIA_CONSTRAINTS: MediaStreamConstraints = {
  audio: false,
  video: { width: 640, height: 360, frameRate: 24 },
};

export const SCREENSHARING_MEDIA_CONSTRAINTS: DisplayMediaStreamConstraints = {
  video: {
    frameRate: { ideal: 20, max: 25 },
    width: 720,
    height: 480,
  },
};

export const LOCAL_PEER_ID = "local-peer";
