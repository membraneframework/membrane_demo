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

import { MembraneWebRTC, isScreenSharingPeer } from "./membraneWebRTC";
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
    screensharing = new MembraneWebRTC(
      getMediaCallbacksFromPhoenixChannel(screensharingChannel),
      {
        peerConfig: {
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
          onLeave: () => {
            screensharingChannel.leave();
            socket.off(screensharingSocketRefs);
            screensharingSocketRefs = [];
          },
        },
      }
    );

    screensharingSocketRefs.push(socket.onError(screensharing.handleError));
    screensharingSocketRefs.push(socket.onClose(screensharing.handleError));

    screensharing.addLocalStream(screenStream);
    screenStream.getTracks().forEach((t) => {
      t.onended = () => {
        cleanLocalScreensharing();
      };
    });
    setLocalScreenSharingStatus(true);

    screensharingChannel.on("mediaEvent", screensharing.receiveEvent);
    const { userId: screensharingUserId } = await phoenixChannelPushResult(
      screensharingChannel.join()
    );
    screensharing.setUserId(screensharingUserId);

    await screensharing.join();
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

    const webrtcSocketRefs: string[] = [];
    const webrtcChannel = socket.channel(
      getChannelId("participant", getRoomId())
    );
    const webrtc = new MembraneWebRTC(
      getMediaCallbacksFromPhoenixChannel(webrtcChannel),
      {
        peerConfig: {
          displayName,
          relayAudio: localAudioStream !== null,
          relayVideo: localVideoStream !== null,
        },
        callbacks: {
          onTrackAdded: ({ stream, peer, isScreenSharing }) => {
            attachStream(stream, peer.id, isScreenSharing);
          },
          onPeerToggledVideo: ({ peer }) => toggleVideoPlaceholder(peer.id),
          onPeerToggledAudio: ({ peer }) => toggleMutedAudioIcon(peer.id),
          onConnectionError: setErrorMessage,
          onPeerJoined: ({ peer, allPeers, isLocalPeer, userId }) => {
            if (!isLocalPeer) {
              if (isScreenSharingPeer(peer)) {
                showScreensharing(peer.displayName, "My screensharing");
              } else {
                addVideoElement(
                  peer.id,
                  peer.displayName,
                  false,
                  false,
                  peer.mutedVideo,
                  peer.mutedAudio
                );
              }
            }

            const participantsNames = allPeers
              .filter((p) => !isScreenSharingPeer(p))
              .map((p) => p.displayName);
            setParticipantsNamesList(participantsNames);

            if (
              !isLocalPeer &&
              !isScreenSharingPeer(peer) &&
              allPeers.filter((p) => !isScreenSharingPeer(p) && p.id !== userId)
                .length <= maxDisplayNum
            ) {
              displayVideoElement(peer.id);
            }
          },
          onPeerLeft: ({ peer, allPeers }) => {
            if (isScreenSharingPeer(peer)) {
              removeScreensharing();
            } else {
              removeVideoElement(peer.id);

              const participantsNames = allPeers
                .filter((p) => !isScreenSharingPeer(p))
                .map((p) => p.displayName);
              setParticipantsNamesList(participantsNames);
            }
          },
          onLeave: () => {
            webrtcChannel.leave();
            socket.off(webrtcSocketRefs);
            while (webrtcSocketRefs.length > 0) {
              webrtcSocketRefs.pop();
            }
          },
        },
      }
    );

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

    const { userId: webrtcUserId } = await phoenixChannelPushResult(
      webrtcChannel.join()
    );
    webrtc.setUserId(webrtcUserId);

    const response = await phoenixChannelPushResult(
      webrtcChannel.push("getMaxDisplayNum", {})
    );
    maxDisplayNum = response.maxDisplayNum;

    webrtcSocketRefs.push(socket.onError(webrtc.handleError));
    webrtcSocketRefs.push(socket.onClose(webrtc.handleError));

    webrtc.addLocalStream(localStream);

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
        onLocalScreensharingStop: stopLocalScreensharing,
        onToggleAudio: () => {
          toggleMutedAudioIcon(LOCAL_PEER_ID);
          webrtc.toggleAudio();
          localAudioStream
            ?.getAudioTracks()
            .forEach((t) => (t.enabled = !t.enabled));
        },
        onToggleVideo: () => {
          toggleVideoPlaceholder(LOCAL_PEER_ID);
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

    await webrtc.join();
  } catch (error) {
    console.error(error);
    setErrorMessage(
      "Failed to setup video room, make sure to grant camera and microphone permissions"
    );
  }
};

setup();
