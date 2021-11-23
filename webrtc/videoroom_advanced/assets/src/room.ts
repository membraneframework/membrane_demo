import {
  LOCAL_PEER_ID,
  AUDIO_MEDIA_CONSTRAINTS,
  VIDEO_MEDIA_CONSTRAINTS,
} from "./consts";
import {
  addVideoElement,
  getRoomId,
  removeVideoElement,
  setErrorMessage,
  setParticipantsList,
  attachStream,
  setupControls,
} from "./room_ui";
import {
  MembraneWebRTC,
  Peer,
  SerializedMediaEvent,
} from "membrane_rtc_engine";
import { Push, Socket } from "phoenix";
import { parse } from "query-string";

export class Room {
  private peers: Peer[] = [];
  private displayName: string;
  private localAudioStream: MediaStream | null = null;
  private localVideoStream: MediaStream | null = null;
  private webrtc: MembraneWebRTC;

  private socket;
  private webrtcSocketRefs: string[] = [];
  private webrtcChannel;

  constructor() {
    this.socket = new Socket("/socket");
    this.socket.connect();
    this.displayName = this.parseUrl();
    this.webrtcChannel = this.socket.channel(`room:${getRoomId()}`);

    this.webrtcSocketRefs.push(this.socket.onError(this.leave));
    this.webrtcSocketRefs.push(this.socket.onClose(this.leave));

    this.webrtc = new MembraneWebRTC({
      callbacks: {
        onSendMediaEvent: (mediaEvent: SerializedMediaEvent) => {
          this.webrtcChannel.push("mediaEvent", { data: mediaEvent });
        },
        onConnectionError: setErrorMessage,
        onJoinSuccess: (peerId, peersInRoom) => {
          this.localAudioStream
            ?.getTracks()
            .forEach((track) =>
              this.webrtc.addTrack(track, this.localAudioStream!)
            );

          this.localVideoStream
            ?.getTracks()
            .forEach((track) =>
              this.webrtc.addTrack(track, this.localVideoStream!)
            );

          this.peers = peersInRoom;
          this.peers.forEach((peer) => {
            addVideoElement(peer.id, peer.metadata.displayName, false);
          });
          this.updateParticipantsList();
        },
        onJoinError: (metadata) => {
          throw `Peer denied.`;
        },
        onTrackReady: ({ stream, peer, metadata }) => {
          attachStream(peer.id, { audioStream: stream, videoStream: stream });
        },
        onTrackAdded: (ctx) => {},
        onTrackRemoved: (ctx) => {},
        onPeerJoined: (peer) => {
          this.peers.push(peer);
          this.updateParticipantsList();
          addVideoElement(peer.id, peer.metadata.displayName, false);
        },
        onPeerLeft: (peer) => {
          this.peers = this.peers.filter((p) => p.id !== peer.id);
          removeVideoElement(peer.id);
          this.updateParticipantsList();
        },
        onPeerUpdated: (ctx) => {},
      },
    });

    this.webrtcChannel.on("mediaEvent", (event: any) =>
      this.webrtc.receiveMediaEvent(event.data)
    );
  }

  public init = async () => {
    try {
      this.localAudioStream = await navigator.mediaDevices.getUserMedia(
        AUDIO_MEDIA_CONSTRAINTS
      );
    } catch (error) {
      console.error("Error while getting local audio stream", error);
    }

    try {
      this.localVideoStream = await navigator.mediaDevices.getUserMedia(
        VIDEO_MEDIA_CONSTRAINTS
      );
    } catch (error) {
      console.error("Error while getting local video stream", error);
    }

    addVideoElement(LOCAL_PEER_ID, "Me", true);

    attachStream(LOCAL_PEER_ID, {
      audioStream: this.localAudioStream,
      videoStream: this.localVideoStream,
    });

    await this.phoenixChannelPushResult(this.webrtcChannel.join());
  };

  public join = () => {
    const callbacks = {
      onLeave: this.leave,
    };
    setupControls(
      {
        audioStream: this.localAudioStream,
        videoStream: this.localVideoStream,
      },
      callbacks
    );

    this.webrtc.join({ displayName: this.displayName });
  };

  private leave = () => {
    this.webrtc.leave();
    this.webrtcChannel.leave();
    this.socket.off(this.webrtcSocketRefs);
    while (this.webrtcSocketRefs.length > 0) {
      this.webrtcSocketRefs.pop();
    }
  };

  private parseUrl = (): string => {
    const { display_name: displayName } = parse(document.location.search);

    // remove query params without reloading the page
    window.history.replaceState(null, "", window.location.pathname);

    return displayName as string;
  };

  private updateParticipantsList = (): void => {
    const participantsNames = this.peers.map((p) => p.metadata.displayName);

    if (this.displayName) {
      participantsNames.push(this.displayName);
    }

    setParticipantsList(participantsNames);
  };

  private phoenixChannelPushResult = async (push: Push): Promise<any> => {
    return new Promise((resolve, reject) => {
      push
        .receive("ok", (response: any) => resolve(response))
        .receive("error", (response: any) => reject(response));
    });
  };
}
