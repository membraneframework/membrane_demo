import "../css/app.scss";

import {
  AUDIO_MEDIA_CONSTRAINTS,
  SCREENSHARING_CONSTRAINTS,
  VIDEO_MEDIA_CONSTRAINTS,
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
  setScreensharing,
  setupRoomUI,
  toggleVideoPlaceholder,
  toggleMutedAudioIcon,
  setParticipantsNamesList,
  linkStreamwWithVideoElement,
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

    screenStream.getTracks().forEach((t) => {
      screensharing?.addLocalTrack(t, screenStream);
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

    try {
      localAudioStream = await navigator.mediaDevices.getUserMedia(
        AUDIO_MEDIA_CONSTRAINTS
      );
    } catch (error) {
      console.error("Couldn't get microphone permission:", error);
    }

    try {
      localVideoStream = await navigator.mediaDevices.getUserMedia(
        VIDEO_MEDIA_CONSTRAINTS
      );
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
        onAddTrack: ({
          stream,
          participant,
          isScreenSharing,
          label: displayName = "",
        }) => {
          if (isScreenSharing) {
            setScreensharing(stream, displayName, "My screensharing");
          } else {
            linkStreamwWithVideoElement(stream, participant.id);
          }
        },
        onRemoveTrack: ({ isScreenSharing }) => {
          if (isScreenSharing) {
            removeScreensharing();
          }
        },
        onDisplayParticipant: displayVideoElement,
        onHideParticipant: hideVideoElement,
        onParticipantToggledVideo: toggleVideoPlaceholder,
        onParticipantToggledAudio: toggleMutedAudioIcon,
        onConnectionError: setErrorMessage,
        onAddParticipant: ({
          participant,
          allParticipants,
          isLocalParticipant,
        }) => {
          if (!isScreenSharingParticipant(participant) && !isLocalParticipant) {
            addVideoElement(
              participant.id,
              participant.displayName,
              false,
              false,
              participant.mutedVideo,
              participant.mutedAudio
            );
          }

          const participantsNames = allParticipants
            .filter((p) => !isScreenSharingParticipant(p))
            .map((p) => p.displayName);
          setParticipantsNamesList(participantsNames);
        },
        onRemoveParticipant: ({ participant, allParticipants }) => {
          if (!isScreenSharingParticipant(participant)) {
            removeVideoElement(participant.id);

            const participantsNames = allParticipants
              .filter((p) => !isScreenSharingParticipant(p))
              .map((p) => p.displayName);
            setParticipantsNamesList(participantsNames);
          }
        },
      },
    });

    if (localAudioStream) {
      localAudioStream
        .getTracks()
        .forEach((track) => webrtc.addLocalTrack(track, localAudioStream!));
    }
    if (localVideoStream) {
      localVideoStream
        .getTracks()
        .forEach((track) => webrtc.addLocalTrack(track, localVideoStream!));
      addVideoElement(
        LOCAL_PARTICIPANT_ID,
        "Me",
        true,
        true,
        false,
        localAudioStream === null
      );
      linkStreamwWithVideoElement(localVideoStream, LOCAL_PARTICIPANT_ID);
      displayVideoElement(LOCAL_PARTICIPANT_ID);
    } else {
      const video = VIDEO_MEDIA_CONSTRAINTS.video as MediaTrackConstraintSet;
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
      linkStreamwWithVideoElement(fakeVideoStream, LOCAL_PARTICIPANT_ID);
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
