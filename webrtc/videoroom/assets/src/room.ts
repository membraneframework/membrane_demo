import "../css/app.scss";

import { MEDIA_CONSTRAINTS, SCREENSHARING_CONSTRAINTS } from "./consts";
import {
  addVideoElement,
  getRoomId,
  removeScreensharing,
  removeVideoElement,
  setErrorMessage,
  setLocalScreenSharingStatus,
  setScreensharing,
  setupRoomUI,
} from "./room_ui";

import { MembraneWebRTC } from "./membraneWebRTC";
import { Socket } from "phoenix";

declare global {
  interface MediaDevices {
    getDisplayMedia: (
      constraints: MediaStreamConstraints
    ) => Promise<MediaStream>;
  }
}

let screensharing: MembraneWebRTC | undefined;

const cleanLocalScreensharing = () => {
  screensharing?.stop();
  screensharing = undefined;
  setLocalScreenSharingStatus(false);
};

const startLocalScreensharing = async (socket: Socket, user: string) => {
  if (screensharing) return;

  try {
    const screenStream = await navigator.mediaDevices.getDisplayMedia(
      SCREENSHARING_CONSTRAINTS
    );

    screensharing = new MembraneWebRTC(socket, getRoomId(), {
      displayName: `${user} Screensharing`,
      type: "screensharing",
      callbacks: {
        onConnectionError: (message) => {
          console.error(message);
          cleanLocalScreensharing();
        },
      },
    });

    screenStream.getTracks().forEach((t) => {
      screensharing?.addTrack(t, screenStream);
      t.onended = () => {
        cleanLocalScreensharing();
      };
    });

    await screensharing.start();
    setLocalScreenSharingStatus(true);
  } catch (error) {
    console.log("Error while starting screensharing", error);
    cleanLocalScreensharing();
  }
};

const stopLocalScreensharing = () => {
  cleanLocalScreensharing();
};

const setup = async () => {
  try {
    const socket = new Socket("/socket");
    socket.connect();

    const displayName = `User #${Math.floor(Math.random() * 10000 + 1)}`;

    const webrtc = new MembraneWebRTC(socket, getRoomId(), {
      displayName,
      callbacks: {
        onAddTrack: ({
          track,
          stream,
          isScreenSharing,
          label: displayName,
        }) => {
          if (isScreenSharing) {
            setScreensharing(stream, displayName || "", "My screensharing");
          } else {
            addVideoElement(track, stream, displayName || "", false);
          }
        },
        onRemoveTrack: ({ track, stream, isScreenSharing }) => {
          if (isScreenSharing) {
            removeScreensharing();
          } else {
            removeVideoElement(track, stream);
          }
        },
        onConnectionError: setErrorMessage,
      },
    });

    const localStream = await navigator.mediaDevices.getUserMedia(
      MEDIA_CONSTRAINTS
    );
    localStream.getTracks().forEach((track) => {
      webrtc.addTrack(track, localStream);
      addVideoElement(track, localStream, "Me", true);
    });

    setupRoomUI({
      state: {
        onLocalScreensharingStart: () =>
          startLocalScreensharing(socket, displayName),
        onLocalScreensharingStop: stopLocalScreensharing,
        onToggleAudio: () =>
          localStream.getAudioTracks().forEach((t) => (t.enabled = !t.enabled)),
        onToggleVideo: () =>
          localStream.getVideoTracks().forEach((t) => (t.enabled = !t.enabled)),
        isLocalScreenSharingActive: false,
        isScreenSharingActive: false,
        displayName,
      },
      muteAudio: false,
      muteVideo: false,
    });

    webrtc.start();
  } catch (error) {
    console.error(error);
    setErrorMessage(
      "Failed to setup video room, make sure to grant camera and microphone permissions"
    );
  }
};

setup();
