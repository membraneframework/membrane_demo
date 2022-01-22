import {
  LOCAL_PEER_ID,
  AUDIO_MEDIA_CONSTRAINTS,
  VIDEO_MEDIA_CONSTRAINTS,
  SCREENSHARING_MEDIA_CONSTRAINTS,
} from "./consts";
import {
  addVideoElement,
  getRoomId,
  removeVideoElement,
  setErrorMessage,
  setParticipantsList,
  attachStream,
  setupControls,
  terminateScreensharing,
  attachScreensharing,
  detachScreensharing,
  toggleScreensharing,
  updateEncoding,
} from "./room_ui";
import {
  MembraneWebRTC,
  Peer,
  SerializedMediaEvent,
  TrackContext,
} from "membrane_rtc_engine";
import { Push, Socket } from "phoenix";
import { parse } from "query-string";

export class Room {
  private peers: Peer[] = [];
  private tracks: Map<string, TrackContext[]> = new Map();
  private displayName: string;
  private localAudioStream: MediaStream | null = null;
  private localVideoStream: MediaStream | null = null;
  private localVideoTrackId: string | null = null;
  private localScreensharing: MediaStream | null = null;
  private localScreensharingTrackId: string | null = null;

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

          this.localVideoStream?.getTracks().forEach((track) => {
            this.localVideoTrackId = this.webrtc.addTrack(
              track,
              this.localVideoStream!,
              {},
              true
            );
          });

          this.peers = peersInRoom;
          this.peers.forEach((peer) => {
            addVideoElement(peer.id, peer.metadata.displayName, false, {
              onLocalSelectEncoding: null,
              onSelectEncoding: this.onSelectEncoding,
            });
            this.tracks.set(peer.id, []);
          });
          this.updateParticipantsList();
        },
        onJoinError: (metadata) => {
          throw `Peer denied.`;
        },
        onTrackReady: (ctx) => {
          if (ctx.metadata && ctx.metadata.type === "screensharing") {
            attachScreensharing(
              ctx.peer.id,
              `(${ctx.peer.metadata.displayName}) Screen`,
              ctx.stream!
            );
          } else {
            attachStream(ctx.peer.id, {
              audioStream: ctx.stream,
              videoStream: ctx.stream,
            });
          }
          this.tracks.get(ctx.peer.id)?.push(ctx);
        },
        onTrackAdded: (ctx) => {},
        onTrackRemoved: (ctx) => {
          if (ctx.metadata.type === "screensharing") {
            detachScreensharing(ctx.peer.id);
          }
          this.tracks
            .get(ctx.peer.id)
            ?.filter((track) => track.trackId == ctx.trackId);
        },
        onPeerJoined: (peer) => {
          this.peers.push(peer);
          this.updateParticipantsList();
          addVideoElement(peer.id, peer.metadata.displayName, false, {
            onLocalSelectEncoding: null,
            onSelectEncoding: this.onSelectEncoding,
          });
        },
        onPeerLeft: (peer) => {
          this.peers = this.peers.filter((p) => p.id !== peer.id);
          removeVideoElement(peer.id);
          this.updateParticipantsList();
        },
        onPeerUpdated: (ctx) => {},
        onTrackEncodingChanged: (
          peerId: string,
          trackId: string,
          encoding: string
        ) => {
          updateEncoding(peerId, encoding);
        },
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

    addVideoElement(LOCAL_PEER_ID, "Me", true, {
      onLocalSelectEncoding: this.onLocalSelectEncoding,
      onSelectEncoding: null,
    });

    attachStream(LOCAL_PEER_ID, {
      audioStream: this.localAudioStream,
      videoStream: this.localVideoStream,
    });

    await this.phoenixChannelPushResult(this.webrtcChannel.join());
  };

  public join = () => {
    const onScreensharingEnd = async () => {
      if (!this.localScreensharing) return;

      this.localScreensharing.getTracks().forEach((track) => track.stop());
      this.localScreensharing = null;

      this.webrtc.removeTrack(this.localScreensharingTrackId!);
      detachScreensharing(LOCAL_PEER_ID);
    };

    const onScreensharingStart = async () => {
      if (this.localScreensharing) return;

      this.localScreensharing = await navigator.mediaDevices.getDisplayMedia(
        SCREENSHARING_MEDIA_CONSTRAINTS
      );

      this.localScreensharingTrackId = this.webrtc.addTrack(
        this.localScreensharing.getVideoTracks()[0],
        this.localScreensharing,
        { type: "screensharing" }
      );

      // listen for screensharing stop via browser controls instead of ui buttons
      this.localScreensharing.getVideoTracks().forEach((track) => {
        track.onended = () => {
          toggleScreensharing(null, onScreensharingEnd)();
        };
      });

      attachScreensharing(
        LOCAL_PEER_ID,
        "(Me) Screen",
        this.localScreensharing
      );
    };

    const callbacks = {
      onLeave: this.leave,
      onScreensharingStart,
      onScreensharingEnd,
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

  private onLocalSelectEncoding = (
    trackType: string,
    encoding: string,
    selected: boolean
  ): void => {
    if (trackType == "video") {
      if (selected) {
        this.webrtc.enableTrackEncoding(this.localVideoTrackId!, encoding);
      } else {
        this.webrtc.disableTrackEncoding(this.localVideoTrackId!, encoding);
      }
    }
  };

  private onSelectEncoding = (peerId: string, encoding: string): void => {
    const trackId = this.tracks
      .get(peerId)
      ?.filter(
        (track) =>
          track.metadata.type != "screensharing" && track.track!.kind == "video"
      )[0].trackId!;
    this.webrtc.selectTrackEncoding(peerId, trackId, encoding);
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
