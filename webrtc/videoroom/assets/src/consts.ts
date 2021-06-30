export const AUDIO_CONSTRAINTS: MediaStreamConstraints = {
  audio: true,
  video: false,
};

export const VIDEO_CONSTRAINTS: MediaStreamConstraints = {
  audio: false,
  video: { width: 640, height: 360, frameRate: 24 },
};

export const LOCAL_PEER_ID = "local-peer";
