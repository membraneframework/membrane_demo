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

let screensharing: MembraneWebRTC | undefined;

const cleanLocalScreensharing = () => {
  screensharing?.stop();
  screensharing = undefined;
  setLocalScreenSharingStatus(false);
};

const startLocalScreensharing = async (socket: Socket) => {
  if (screensharing) return;

  try {
    const screenStream = await navigator.mediaDevices.getDisplayMedia(
      SCREENSHARING_CONSTRAINTS
    );

    screensharing = new MembraneWebRTC(
      socket,
      `room:screensharing:${getRoomId()}`,
      {
        onConnectionError: (message) => {
          console.error(message);
          cleanLocalScreensharing();
        },
      }
    );

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

    const webrtc = new MembraneWebRTC(socket, `room:${getRoomId()}`, {
      onAddTrack: addVideoElement,
      onRemoveTrack: removeVideoElement,
      onConnectionError: setErrorMessage,
      onScreensharingStart: setScreensharing,
      onScreensharingEnd: removeScreensharing,
    });

    const localStream = await navigator.mediaDevices.getUserMedia(
      MEDIA_CONSTRAINTS
    );
    localStream.getTracks().forEach((track) => {
      webrtc.addTrack(track, localStream);
      addVideoElement(track, localStream, true);
    });

    setupRoomUI({
      state: {
        onLocalScreensharingStart: () => startLocalScreensharing(socket),
        onLocalScreensharingStop: stopLocalScreensharing,
        onToggleAudio: () =>
          localStream.getAudioTracks().forEach((t) => (t.enabled = !t.enabled)),
        onToggleVideo: () =>
          localStream.getVideoTracks().forEach((t) => (t.enabled = !t.enabled)),
        isLocalScreenSharingActive: false,
        isScreenSharingActive: false,
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
