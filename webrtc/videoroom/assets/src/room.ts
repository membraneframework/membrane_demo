import "../css/app.scss";

import { getRoomId, addVideoElement, removeVideoElement, setErrorMessage } from "./room_ui";

import { MembraneWebRTC } from "./membraneWebRTC";
import { Socket } from "phoenix";

const MEDIA_CONSTRAINTS = {
  audio: true,
  video: { width: 1280, height: 720 },
};

const setup = async () => {
  try {
    const socket = new Socket("/socket");
    socket.connect();

    const webrtc = new MembraneWebRTC(socket, `room:${getRoomId()}`, {
      onAddTrack: addVideoElement,
      onRemoveTrack: removeVideoElement,
      onConnectionError: setErrorMessage,
    });

    const localStream = await navigator.mediaDevices.getUserMedia(
      MEDIA_CONSTRAINTS
    );
    localStream
      .getTracks()
      .forEach(track => {
        webrtc.addTrack(track, localStream);
        addVideoElement(track, localStream, true);
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
