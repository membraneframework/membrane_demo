import "../css/app.scss";

import {
  AUDIO_CONSTRAINTS,
  SCREENSHARING_CONSTRAINTS,
  VIDEO_CONSTRAINTS,
  LOCAL_PEER_ID,
} from "./consts";
import {
  addVideoElement,
  displayVideoElement,
  getRoomId,
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
import {
  getMediaCallbacksFromPhoenixChannel,
  getChannelId,
  phoenixChannelPushResult,
} from "../src/utils";
import { MembraneWebRTC, Peer } from "./membraneWebRTC";
import { Socket } from "phoenix";
import { parse } from "query-string";
import { v4 as uuidv4 } from "uuid";

declare global {
  interface MediaDevices {
    getDisplayMedia: (
      constraints: MediaStreamConstraints
    ) => Promise<MediaStream>;
  }
}

let screensharingSocketRefs: string[] = [];
let screensharing: MembraneWebRTC | undefined;

let peers: Peer[] = [];
let webRtcPeerId: string | undefined;
let displayName: string | undefined;

const cleanLocalScreensharing = () => {
  screensharing?.leave();
  screensharing = undefined;
  setLocalScreenSharingStatus(false);
};

const startLocalScreensharing = async (socket: Socket, user: string) => {
  if (screensharing) return;

  try {
    const screenStream = await navigator.mediaDevices.getDisplayMedia(
      SCREENSHARING_CONSTRAINTS
    );

    const screensharingChannel = socket.channel(
      getChannelId("screensharing", getRoomId())
    );
    screensharing = new MembraneWebRTC({
      peerConfig: {
        relayVideo: true,
        relayAudio: false,
      },
      callbacks: {
        ...getMediaCallbacksFromPhoenixChannel(screensharingChannel),
        onConnectionError: (message) => {
          console.error(message);
          cleanLocalScreensharing();
        },
      },
    });

    const leave = () => {
      screensharingChannel.leave();
      socket.off(screensharingSocketRefs);
      screensharingSocketRefs = [];
    };

    screensharingSocketRefs.push(socket.onError(leave));
    screensharingSocketRefs.push(socket.onClose(leave));

    screenStream.getTracks().forEach((t) => {
      screensharing?.addLocalTrack(t, screenStream);
      t.onended = () => {
        cleanLocalScreensharing();
      };
    });
    setLocalScreenSharingStatus(true);

    screensharingChannel.on("mediaEvent", screensharing.receiveEvent);
    await phoenixChannelPushResult(screensharingChannel.join());

    screensharing.join({
      displayName: `${user} Screensharing`,
      type: "screensharing",
      mutedAudio: true,
      mutedVideo: false,
    });

    // if (!accepted) {
    //   cleanLocalScreensharing();
    //   setLocalScreenSharingStatus(false);
    // }
  } catch (error) {
    console.log("Error while starting screensharing", error);
    cleanLocalScreensharing();
    setLocalScreenSharingStatus(false);
  }
};

const parseUrl = (): string => {
  const { display_name: displayName } = parse(document.location.search);

  // remove query params without reloading the page
  window.history.replaceState(null, "", window.location.pathname);

  return displayName as string;
};

const updateParticipantsList = (peersList: Peer[]): void => {
  const participantsNames = peers
    .filter((p) => p.metadata.type !== "screensharing")
    .map((p) => p.metadata.displayName);

  if (displayName) {
    participantsNames.push(displayName);
  }

  setParticipantsNamesList(participantsNames);
};

const setup = async () => {
  try {
    const socket = new Socket("/socket");
    socket.connect();

    displayName = parseUrl();

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

    const webrtcSocketRefs: string[] = [];
    const metadata = {};
    const webrtcChannel = socket.channel(
      getChannelId("participant", getRoomId()),
      { metadata: metadata }
    );

    const relayAudio = localAudioStream !== null;
    const relayVideo = localVideoStream !== null;

    const webrtc = new MembraneWebRTC({
      peerConfig: { relayAudio, relayVideo },
      callbacks: {
        ...getMediaCallbacksFromPhoenixChannel(webrtcChannel),
        onTrackAdded: ({ stream, peer, metadata }) => {
          attachStream(stream, peer.id);
        },
        onConnectionError: setErrorMessage,
        onJoined: (peerId, peersInRoom) => {
          peers = peersInRoom!;
          webRtcPeerId = peerId;
          peers.forEach((peer) => {
            addVideoElement(
              peer.id,
              peer.metadata.displayName,
              false,
              false,
              peer.metadata.mutedVideo,
              peer.metadata.mutedAudio
            );
            displayVideoElement(peer.id);
          });
        },
        onDenied: () => {
          console.log("onDenied");
        },

        onPeerJoined: (peer) => {
          peers.push(peer);
          // const isLocalPeer = peer.id === webRtcPeerId;

          // if (!isLocalPeer) {
          //   if (peer.metadata.type === "screensharing") {
          //     showScreensharing(peer.metadata.displayName, "My screensharing");
          //   } else {
          addVideoElement(
            peer.id,
            peer.metadata.displayName,
            false,
            false,
            peer.metadata.mutedVideo,
            peer.metadata.mutedAudio
          );
          //   }
          // }

          updateParticipantsList(peers);

          // if (!isLocalPeer && peer.metadata.type !== "screensharing") {
          displayVideoElement(peer.id);
          // }
        },
        onPeerLeft: (peer) => {
          peers = peers.filter((p) => p.id !== peer.id);

          if (peer.metadata.type === "screensharing") {
            removeScreensharing();
          } else {
            removeVideoElement(peer.id);
            updateParticipantsList(peers);
          }
        },
      },
    });

    webrtcChannel.on("mediaEvent", (event) => webrtc.receiveEvent(event.data));
    webrtcChannel.on("peerToggledVideo", (data: any) =>
      toggleVideoPlaceholder(data.data.peerId)
    );
    webrtcChannel.on("peerToggledAudio", (data: any) =>
      toggleMutedAudioIcon(data.data.peerId)
    );

    await phoenixChannelPushResult(webrtcChannel.join());

    const leave = () => {
      webrtc.leave();
      webrtcChannel.leave();
      socket.off(webrtcSocketRefs);
      while (webrtcSocketRefs.length > 0) {
        webrtcSocketRefs.pop();
      }
    };

    webrtcSocketRefs.push(socket.onError(leave));
    webrtcSocketRefs.push(socket.onClose(leave));

    localStream
      .getTracks()
      .forEach((track) => webrtc.addLocalTrack(track, localStream));

    if (localVideoStream) {
      addVideoElement(
        LOCAL_PEER_ID,
        "Me",
        true,
        true,
        false,
        localAudioStream === null
      );
      attachStream(localStream, LOCAL_PEER_ID);
      displayVideoElement(LOCAL_PEER_ID);
    } else {
      addVideoElement(
        LOCAL_PEER_ID,
        "Me",
        true,
        true,
        true,
        localAudioStream === null
      );
      displayVideoElement(LOCAL_PEER_ID);
    }

    setupRoomUI({
      state: {
        onLocalScreensharingStart: () =>
          startLocalScreensharing(socket, displayName),
        onLocalScreensharingStop: cleanLocalScreensharing,
        onToggleAudio: () => {
          toggleMutedAudioIcon(LOCAL_PEER_ID);
          webrtcChannel.push("toggledAudio", {});
          localAudioStream
            ?.getAudioTracks()
            .forEach((t) => (t.enabled = !t.enabled));
        },
        onToggleVideo: () => {
          toggleVideoPlaceholder(LOCAL_PEER_ID);
          webrtcChannel.push("toggledVideo", {});
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

    webrtc.join({
      displayName,
      type: "participant",
      mutedAudio: !relayAudio,
      mutedVideo: !relayVideo,
    });
  } catch (error) {
    console.error(error);
    setErrorMessage(
      "Failed to setup video room, make sure to grant camera and microphone permissions"
    );
  }
};

setup();
