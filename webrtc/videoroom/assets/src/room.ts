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
import {
  getMediaCallbacksFromPhoenixChannel,
  getChannelId,
  phoenixChannelPushResult,
} from "../src/utils";
import {
  MembraneWebRTC,
  isScreenSharingPeer,
  Peer,
  generateRandomString,
} from "./membraneWebRTC";
import { Socket } from "phoenix";
import { parse } from "query-string";

declare global {
  interface MediaDevices {
    getDisplayMedia: (
      constraints: MediaStreamConstraints
    ) => Promise<MediaStream>;
  }
}

let screensharingSocketRefs: string[] = [];
let screensharing: MembraneWebRTC | undefined;
let maxDisplayNum: number = 1;

let peers: Peer[] = [];
let webRtcPeerId: string | undefined;

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
    screensharing = new MembraneWebRTC(generateRandomString(), {
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

    const { accepted } = await screensharing.join({
      displayName: `${user} Screensharing`,
      type: "screensharing",
      mutedAudio: true,
      mutedVideo: false,
    });

    if (!accepted) {
      cleanLocalScreensharing();
      setLocalScreenSharingStatus(false);
    }
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

    const webrtcSocketRefs: string[] = [];
    const metadata = {};
    const webrtcChannel = socket.channel(
      getChannelId("participant", getRoomId()),
      { metadata: metadata }
    );

    const relayAudio = localAudioStream !== null;
    const relayVideo = localVideoStream !== null;

    const webrtc = new MembraneWebRTC(generateRandomString(), {
      peerConfig: { relayAudio, relayVideo },
      callbacks: {
        ...getMediaCallbacksFromPhoenixChannel(webrtcChannel),
        onTrackAdded: ({ stream, peer, metadata }) => {
          attachStream(stream, peer.id, metadata.type === "screensharing");
        },
        onConnectionError: setErrorMessage,
        onPeerJoined: (peer) => {
          const isLocalPeer = peer.id === webRtcPeerId;

          if (!isLocalPeer) {
            if (isScreenSharingPeer(peer)) {
              showScreensharing(peer.metadata.displayName, "My screensharing");
            } else {
              addVideoElement(
                peer.id,
                peer.metadata.displayName,
                false,
                false,
                peer.metadata.mutedVideo,
                peer.metadata.mutedAudio
              );
            }
          }

          const participantsNames = peers
            .filter((p) => !isScreenSharingPeer(p))
            .map((p) => p.metadata.displayName);
          setParticipantsNamesList(participantsNames);

          if (
            !isLocalPeer &&
            !isScreenSharingPeer(peer) &&
            peers.filter(
              (p) => !isScreenSharingPeer(p) && p.id !== webRtcPeerId
            ).length <= maxDisplayNum
          ) {
            displayVideoElement(peer.id);
          }
        },
        onPeerLeft: (peer) => {
          peers = peers.filter((p) => p.id !== peer.id);
          if (isScreenSharingPeer(peer)) {
            removeScreensharing();
          } else {
            removeVideoElement(peer.id);

            const participantsNames = peers
              .filter((p) => !isScreenSharingPeer(p))
              .map((p) => p.metadata.displayName);
            setParticipantsNamesList(participantsNames);
          }
        },
      },
    });

    webrtcChannel.on("mediaEvent", webrtc.receiveEvent);
    webrtcChannel.on("replacePeer", (data: any) => {
      const oldPeerId = data.data.oldPeerId;
      const newPeerId = data.data.newPeerId;

      hideVideoElement(oldPeerId);
      displayVideoElement(newPeerId);
    });
    webrtcChannel.on("displayPeer", (data: any) =>
      displayVideoElement(data.data.peerId)
    );
    webrtcChannel.on("peerToggledVideo", (data: any) =>
      toggleVideoPlaceholder(data.data.peerId)
    );
    webrtcChannel.on("peerToggledAudio", (data: any) =>
      toggleMutedAudioIcon(data.data.peerId)
    );

    await phoenixChannelPushResult(webrtcChannel.join());

    const response = await phoenixChannelPushResult(
      webrtcChannel.push("getMaxDisplayNum", {})
    );
    maxDisplayNum = response.maxDisplayNum;

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

    const { accepted, peersInRoom, id } = await webrtc.join({
      displayName,
      type: "participant",
      mutedAudio: !relayAudio,
      mutedVideo: !relayVideo,
    });
    if (accepted) {
      peers = peersInRoom!;
      webRtcPeerId = id;
    }
  } catch (error) {
    console.error(error);
    setErrorMessage(
      "Failed to setup video room, make sure to grant camera and microphone permissions"
    );
  }
};

setup();
