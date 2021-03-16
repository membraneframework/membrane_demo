import "../css/app.scss";

import {
  addVideoElement,
  removePlayerLinks,
  removeVideoElement,
  setErrorMessage,
  setPlayerLinks,
} from "./ui";

import { MembraneWebRTC } from "./membraneWebRTC";
import { Socket } from "phoenix";

const CONSTRAINTS = {
  audio: true,
  video: { width: 1280, height: 720 },
};

const setup = async () => {
  const socket = new Socket("/socket");
  socket.connect();

  const roomEl = document.getElementById("room");
  if (roomEl) {
    try {
      const localStream = await navigator.mediaDevices.getUserMedia(
        CONSTRAINTS
      );

      localStream
        .getTracks()
        .forEach((track) => addVideoElement(track, localStream, true));

      new MembraneWebRTC(socket, localStream, {
        onAddTrack: addVideoElement,
        onRemoveTrack: removeVideoElement,
        onConnectionError: (message: string) => {
          setErrorMessage(message);
          removePlayerLinks();
        },
        onHlsPath: setPlayerLinks,
      }).start();
    } catch (error) {
      console.error(error);
      setErrorMessage(
        "Failed to setup video room, make sure to grant camera and microphone permissions"
      );
    }
  } else {
    console.error("room element is missing, cannot join video room");
  }
};

setup();
