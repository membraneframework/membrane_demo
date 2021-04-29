import "../css/app.scss";

import {
  AUDIO_MEDIA_CONSTRAINTS,
  SCREENSHARING_CONSTRAINTS,
  VIDEO_MEDIA_CONSTRAINTS,
} from "./consts";
import {
  addAudioElement,
  addVideoElement,
  getRoomId,
  removeAudioElement,
  removeScreensharing,
  removeVideoElement,
  replaceStream,
  setErrorMessage,
  setLocalScreenSharingStatus,
  setScreensharing,
  setupRoomUI,
} from "./room_ui";

import { MembraneWebRTC } from "./membraneWebRTC";
import { Socket } from "phoenix";
import { createFakeVideoStream } from "./utils";
import { parse } from "query-string";

declare global {
  interface MediaDevices {
    getDisplayMedia: (
      constraints: MediaStreamConstraints
    ) => Promise<MediaStream>;
  }
  interface HTMLCanvasElement {
    captureStream(frameRate?: number): MediaStream;
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
      signalingOptions: {
        displayName: `${user} Screensharing`,
        relayVideo: true,
        relayAudio: false,
      },
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

const getDisplayNameOrRedirect = (): string => {
  const { display_name: displayName } = parse(document.location.search);

  // remove query params without reloading the page
  window.history.replaceState(null, "", window.location.pathname);

  return displayName as string;
};

const setup = async () => {
  try {
    const socket = new Socket("/socket");
    socket.connect();

    const displayName = getDisplayNameOrRedirect();

    let localAudioStream: MediaStream | null = null;
    let localVideoStream: MediaStream | null = null;

    try {
      localAudioStream = await navigator.mediaDevices.getUserMedia(
        AUDIO_MEDIA_CONSTRAINTS
      );
    } catch (error) {
      console.error(
        "Couldn't get microphone permission:",
        error
      );
    }

    try {
      localVideoStream = await navigator.mediaDevices.getUserMedia(
        VIDEO_MEDIA_CONSTRAINTS
      );
    } catch (error) {
      console.error(
        "Couldn't get camera permission:",
        error
      );
    }

    const webrtc = new MembraneWebRTC(socket, getRoomId(), {
      signalingOptions: {
        displayName,
        relayAudio: localAudioStream !== null,
        relayVideo: localVideoStream !== null,
      },
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
            addAudioElement(stream);
          }
        },
        onRemoveTrack: ({ track, stream, isScreenSharing }) => {
          if (isScreenSharing) {
            removeScreensharing();
          } else {
            removeVideoElement(stream);
            removeAudioElement(stream);
          }
        },
        onReplaceStream: replaceStream,
        onDisplayStream: addVideoElement,
        onConnectionError: setErrorMessage,
      },
    });

    if (localAudioStream) {
      localAudioStream
        .getTracks()
        .forEach((track) => webrtc.addTrack(track, localAudioStream!));
    }
    if (localVideoStream) {
      localVideoStream
        .getTracks()
        .forEach((track) => webrtc.addTrack(track, localVideoStream!));
      addVideoElement(localVideoStream, "Me", true);
    } else {
      const video = VIDEO_MEDIA_CONSTRAINTS.video as MediaTrackConstraintSet;
      const fakeVideoStream = createFakeVideoStream({
        height: video!.height as number,
        width: video.width! as number,
      });
      addVideoElement(fakeVideoStream, "Me", true);
    }

    setupRoomUI({
      state: {
        onLocalScreensharingStart: () =>
          startLocalScreensharing(socket, displayName),
        onLocalScreensharingStop: stopLocalScreensharing,
        onToggleAudio: () =>
          localAudioStream
            ?.getAudioTracks()
            .forEach((t) => (t.enabled = !t.enabled)),
        onToggleVideo: () =>
          localVideoStream
            ?.getVideoTracks()
            .forEach((t) => (t.enabled = !t.enabled)),
        isLocalScreenSharingActive: false,
        isScreenSharingActive: false,
        displayName,
      },
      muteAudio: false,
      muteVideo: false,
      enableAudio: localAudioStream !== null,
      enableVideo: localVideoStream !== null,
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
