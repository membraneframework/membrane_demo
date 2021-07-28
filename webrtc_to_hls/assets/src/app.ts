import "../css/app.scss";

import { MembraneWebRTC, SerializedMediaEvent } from "membrane_rfc_engine";
import { Push, Socket } from "phoenix";
import { setErrorMessage, setPlayerInfo, setPreview } from "./ui";

declare global {
  interface MediaDevices {
    getDisplayMedia: (
      constraints: MediaStreamConstraints
    ) => Promise<MediaStream>;
  }
}

const awaitPhoenixPush = async (push: Push): Promise<any> => {
  return new Promise((resolve, reject) => {
    push
      .receive("ok", (response: any) => resolve(response))
      .receive("error", (response: any) => reject(response));
  });
};

export const AUDIO_CONSTRAINTS: MediaStreamConstraints = {
  audio: true,
  video: false,
};

export const VIDEO_CONSTRAINTS: MediaStreamConstraints = {
  audio: false,
  video: { width: 640, height: 360, frameRate: 24 },
};

export const LOCAL_PEER_ID = "local-peer";

const setup = async () => {
  const socket = new Socket("/socket");
  socket.connect();

  let localAudioStream: MediaStream | null = null;
  let localVideoStream: MediaStream | null = null;
  let localStream: MediaStream = new MediaStream();

  try {
    localAudioStream = await navigator.mediaDevices.getUserMedia(
      AUDIO_CONSTRAINTS
    );
    localAudioStream
      .getTracks()
      .forEach((track) => localStream.addTrack(track));
  } catch (error) {
    console.error("Couldn't get microphone permission:", error);
  }

  try {
    localVideoStream = await navigator.mediaDevices.getUserMedia(
      VIDEO_CONSTRAINTS
    );
    localVideoStream
      .getTracks()
      .forEach((track) => localStream.addTrack(track));
  } catch (error) {
    console.error("Couldn't get camera permission:", error);
  }

  setPreview(localStream);

  const webrtcChannel = socket.channel("stream");

  const onError = (error: any) => {
    setErrorMessage(error);

    webrtc.leave();
    webrtcChannel.leave();
  };

  webrtcChannel.onError(onError);

  const webrtc = new MembraneWebRTC({
    callbacks: {
      onSendMediaEvent: (mediaEvent: SerializedMediaEvent) => {
        webrtcChannel.push("mediaEvent", { data: mediaEvent });
      },
    },
  });

  await awaitPhoenixPush(webrtcChannel.join());

  localStream
    .getTracks()
    .forEach((track) => webrtc.addTrack(track, localStream));

  webrtc.join({
    displayName: "It's me, Mario!",
  });

  webrtcChannel.on("mediaEvent", (event) =>
    webrtc.receiveMediaEvent(event.data)
  );
  webrtcChannel.on("playlistPlayable", ({ playlistId }) => {
    console.log("HLS playlist has become playable: ", playlistId);
    setPlayerInfo(playlistId);
  });
};

setup();
