import "../css/app.scss";

import {
  AUDIO_CONSTRAINTS,
  SCREENSHARING_CONSTRAINTS,
  VIDEO_CONSTRAINTS,
  LOCAL_PARTICIPANT_ID,
} from "./consts";
import {
  addVideoElement,
  displayVideoElement,
  getRoomId,
  hideVideoElement,
  removeScreensharing,
  removeVideoElement,
  setErrorMessage,
  setLocalScreenSharingStatus,
  showScreensharing,
  setupRoomUI,
  toggleVideoPlaceholder,
  toggleMutedAudioIcon,
  setParticipantsNamesList,
  attachStream,
} from "./room_ui";
import { createFakeVideoStream } from "../src/utils";

import { MembraneWebRTC, isScreenSharingParticipant } from "./membraneWebRTC";
import { Socket } from "phoenix";
import { parse } from "query-string";

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
      participantConfig: {
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

    screensharing?.addLocalStream(screenStream);
    screenStream.getTracks().forEach((t) => {
      t.onended = () => {
        cleanLocalScreensharing();
      };
    });
    setLocalScreenSharingStatus(true);

    await screensharing.start();
  } catch (error) {
    console.log("Error while starting screensharing", error);
    cleanLocalScreensharing();
    setLocalScreenSharingStatus(false);
  }
};

const stopLocalScreensharing = () => {
  cleanLocalScreensharing();
};

const parseUrl = (): string => {
  const { display_name: displayName } = parse(document.location.search);

  // remove query params without reloading the page
  window.history.replaceState(null, "", window.location.pathname);

  return displayName as string;
};

const setup = async () => {
  try {
    const socket = new Socket("/socket");
    socket.connect();

    const displayName = parseUrl();

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

    const webrtc = new MembraneWebRTC(socket, getRoomId(), {
      participantConfig: {
        displayName,
        relayAudio: localAudioStream !== null,
        relayVideo: localVideoStream !== null,
      },
      callbacks: {
        onAddTrack: ({ stream, participant, isScreenSharing }) => {
          attachStream(stream, participant.id, isScreenSharing);
        },
        onDisplayParticipant: displayVideoElement,
        onHideParticipant: hideVideoElement,
        onParticipantToggledVideo: toggleVideoPlaceholder,
        onParticipantToggledAudio: toggleMutedAudioIcon,
        onConnectionError: setErrorMessage,
        onParticipantJoined: ({
          participant,
          allParticipants,
          isLocalParticipant,
        }) => {
          if (!isLocalParticipant) {
            if (isScreenSharingParticipant(participant)) {
              showScreensharing(participant.displayName, "My screensharing");
            } else {
              addVideoElement(
                participant.id,
                participant.displayName,
                false,
                false,
                participant.mutedVideo,
                participant.mutedAudio
              );
            }
          }

          const participantsNames = allParticipants
            .filter((p) => !isScreenSharingParticipant(p))
            .map((p) => p.displayName);
          setParticipantsNamesList(participantsNames);
        },
        onParticipantLeft: ({ participant, allParticipants }) => {
          if (isScreenSharingParticipant(participant)) {
            removeScreensharing();
          } else {
            removeVideoElement(participant.id);

            const participantsNames = allParticipants
              .filter((p) => !isScreenSharingParticipant(p))
              .map((p) => p.displayName);
            setParticipantsNamesList(participantsNames);
          }
        },
      },
    });

    webrtc.addLocalStream(localStream);

    if (localVideoStream) {
      addVideoElement(
        LOCAL_PARTICIPANT_ID,
        "Me",
        true,
        true,
        false,
        localAudioStream === null
      );
      attachStream(localStream, LOCAL_PARTICIPANT_ID);
      displayVideoElement(LOCAL_PARTICIPANT_ID);
    } else {
      const video = VIDEO_CONSTRAINTS.video as MediaTrackConstraintSet;
      const fakeVideoStream = createFakeVideoStream({
        height: video!.height as number,
        width: video.width! as number,
      }) as MediaStream;
      addVideoElement(
        LOCAL_PARTICIPANT_ID,
        "Me",
        true,
        true,
        true,
        localAudioStream === null
      );
      attachStream(fakeVideoStream, LOCAL_PARTICIPANT_ID);
      displayVideoElement(LOCAL_PARTICIPANT_ID);
    }

    setupRoomUI({
      state: {
        onLocalScreensharingStart: () =>
          startLocalScreensharing(socket, displayName),
        onLocalScreensharingStop: stopLocalScreensharing,
        onToggleAudio: () => {
          toggleMutedAudioIcon(LOCAL_PARTICIPANT_ID);
          webrtc.toggleAudio();
          localAudioStream
            ?.getAudioTracks()
            .forEach((t) => (t.enabled = !t.enabled));
        },
        onToggleVideo: () => {
          toggleVideoPlaceholder(LOCAL_PARTICIPANT_ID);
          webrtc.toggleVideo();
          localVideoStream
            ?.getVideoTracks()
            .forEach((t) => (t.enabled = !t.enabled));
        },
        isLocalScreenSharingActive: false,
        isScreenSharingActive: false,
        displayName,
      },
      audioState: localAudioStream === null ? "disabled" : "unmuted",
      videoState: localVideoStream === null ? "disabled" : "unmuted",
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
