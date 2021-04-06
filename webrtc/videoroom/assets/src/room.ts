import "../css/app.scss";

import { MEDIA_CONSTRAINTS, SCREENSHARING_CONSTRAINTS } from "./consts";
import {
  addVideoElement,
  getRoomId,
  removeScreensharing,
  removeVideoElement,
  setErrorMessage,
  setScreensharing,
  setupRoomUI,
} from "./room_ui";

import { MembraneWebRTC } from "./membraneWebRTC";
import { Socket } from "phoenix";

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

    const onLocalScreensharingStart = async () => {
      const getLocalScreensharing = async () => {
        return navigator.mediaDevices.getDisplayMedia(
          SCREENSHARING_CONSTRAINTS
        );
      };

      webrtc.startScreensharing(getLocalScreensharing);
    };

    const onLocalScreensharingStop = async () => {
      webrtc.stopScreensharing();
    };

    setupRoomUI({ onLocalScreensharingStart, onLocalScreensharingStop });

    webrtc.start();
  } catch (error) {
    console.error(error);
    setErrorMessage(
      "Failed to setup video room, make sure to grant camera and microphone permissions"
    );
  }
};

setup();
