export type SerializedMediaEvent = string;

export interface Peer {
  id: string;
  metadata: any;
  midToTrackMetadata: Map<string, any>;
}

export interface MembraneWebRTCConfig {
  callbacks: Callbacks;
  rtcConfig?: RTCConfiguration;
  receiveMedia?: boolean;
  peerConfig: PeerConfig;
}

interface OfferData {
  data: RTCSessionDescriptionInit;
}

interface CandidateData {
  data: RTCIceCandidateInit;
}

interface MediaEvent {
  type: string;
  key?: string;
  data?: any;
}

interface TrackContext {
  track: MediaStreamTrack;
  stream: MediaStream;
  peer: Peer;
  mid: string;
  metadata: any;
}

interface PeerConfig {
  relayVideo: boolean;
  relayAudio: boolean;
}

interface JoinResult {
  accepted: boolean;
  id?: string;
  peersInRoom?: Peer[];
}

interface Callbacks {
  onSendSerializedMediaEvent: (
    serializedMediaEvent: SerializedMediaEvent
  ) => void;
  onSendSerializedMediaEventResult: (
    serializedMediaEvent: SerializedMediaEvent
  ) => Promise<any>;

  onTrackAdded?: (ctx: TrackContext) => void;
  onTrackRemoved?: (ctx: TrackContext) => void;

  onPeerJoined?: (peer: Peer) => void;
  onPeerLeft?: (peer: Peer) => void;

  onConnectionError?: (message: string) => void;
}

export function isScreenSharingPeer(peer: Peer): boolean {
  return (
    Array.from(peer.midToTrackMetadata.keys()).find((mid) =>
      mid.includes("SCREEN")
    ) !== undefined
  );
}

export function generateRandomString(): string {
  return (
    Math.random().toString(36).substring(2) +
    Math.random().toString(36).substring(2) +
    Math.random().toString(36).substring(2)
  );
}

function serializeMediaEvent(mediaEvent: MediaEvent): SerializedMediaEvent {
  return JSON.stringify(mediaEvent);
}

function deserializeMediaEvent(
  serializedMediaEvent: SerializedMediaEvent
): MediaEvent {
  return JSON.parse(serializedMediaEvent) as MediaEvent;
}

export class MembraneWebRTC {
  private key: string;
  private id: string;

  private receiveMedia: boolean;

  private localTracksWithStreams: {
    track: MediaStreamTrack;
    stream: MediaStream;
  }[] = [];
  private midToTrackMetadata: Map<string, any> = new Map();
  private localTrackIdToMetadata: Map<string, any> = new Map();
  private midToStream: Map<String, MediaStream> = new Map();
  private connection?: RTCPeerConnection;
  private idToPeer: Map<String, Peer> = new Map();
  private midToPeer: Map<String, Peer> = new Map();
  private readonly rtcConfig: RTCConfiguration = {
    iceServers: [
      {
        urls: "stun:stun.l.google.com:19302",
      },
    ],
  };

  private readonly callbacks: Callbacks;

  constructor(id: string, config: MembraneWebRTCConfig) {
    const { receiveMedia = true, callbacks, rtcConfig, peerConfig } = config;

    this.receiveMedia = receiveMedia;

    this.callbacks = callbacks;
    this.rtcConfig = rtcConfig || this.rtcConfig;

    this.key = generateRandomString();
    this.id = id;
  }

  public join = async (peerMetadata: any): Promise<JoinResult> => {
    try {
      let relayAudio = false,
        relayVideo = false;

      this.localTracksWithStreams.forEach(({ stream }) => {
        if (stream.getAudioTracks() !== []) relayAudio = true;
        if (stream.getVideoTracks() !== []) relayVideo = true;
      });

      const serializedResponse = await this.onSendMediaEventResult({
        type: "join",
        key: this.key,
        data: {
          id: this.id,
          relayAudio: relayAudio,
          relayVideo: relayVideo,
          receiveMedia: this.receiveMedia,
          metadata: peerMetadata,
          tracksMetadata: Array.from(this.localTrackIdToMetadata.values()),
        },
      });
      const response = deserializeMediaEvent(serializedResponse);

      if (response.type === "peerAccepted") {
        const result = {
          ...response.data,
          accepted: true,
        } as JoinResult;

        result.peersInRoom?.forEach((peer) => this.addPeer(peer));

        return result;
      } else {
        return { accepted: false };
      }
    } catch (e) {
      this.callbacks.onConnectionError?.(e);
      this.leave();
      return { accepted: false };
    }
  };

  public receiveEvent = (serializedMediaEvent: SerializedMediaEvent) => {
    const mediaEvent = deserializeMediaEvent(serializedMediaEvent);

    switch (mediaEvent.type) {
      case "offer":
        this.onOffer(mediaEvent.data);
        break;

      case "candidate":
        this.onRemoteCandidate(mediaEvent.data);
        break;

      case "peerJoined":
        const peer = mediaEvent.data.peer;
        this.onPeerJoined(peer);
        break;

      case "peerLeft":
        this.onPeerLeft(mediaEvent.data.peerId);
        break;

      case "error":
        this.callbacks.onConnectionError?.(mediaEvent.data.message);
        this.leave();
        break;
    }
  };

  public addLocalTrack(
    track: MediaStreamTrack,
    stream: MediaStream,
    trackMetadata: any = {}
  ) {
    this.localTracksWithStreams.push({ track, stream });
    this.localTrackIdToMetadata.set(track.id, trackMetadata);
  }

  public leave = () => {
    this.onSendMediaEvent({ type: "leave", key: this.key });
    this.cleanUp();
  };

  public cleanUp = () => {
    if (this.connection) {
      this.connection.onicecandidate = null;
      this.connection.ontrack = null;
    }

    this.localTracksWithStreams.forEach(({ track }) => track.stop());
    this.localTracksWithStreams = [];
    this.connection = undefined;
  };

  private onOffer = async (offer: OfferData) => {
    if (!this.connection) {
      this.connection = new RTCPeerConnection(this.rtcConfig);
      this.connection.onicecandidate = this.onLocalCandidate();
      this.connection.ontrack = this.onTrack();

      this.localTracksWithStreams.forEach(({ track, stream }) => {
        this.connection!.addTrack(track, stream);
      });
    } else {
      this.connection.createOffer({ iceRestart: true });
    }

    try {
      await this.connection.setRemoteDescription(offer.data);
      const answer = await this.connection.createAnswer();
      await this.connection.setLocalDescription(answer);

      const localMidToTrackMetadata = new Map();

      this.connection.getTransceivers().forEach((transceiver) => {
        const trackId = transceiver.sender.track?.id;
        const mid = transceiver.mid;

        if (trackId && mid) {
          this.midToTrackMetadata.set(
            mid,
            this.localTrackIdToMetadata.get(trackId)
          );
        }
      });

      this.onSendMediaEvent({
        type: "sdpAnswer",
        key: this.key,
        data: answer,
      });
    } catch (error) {
      console.error(error);
    }
  };

  private onRemoteCandidate = (candidate: CandidateData) => {
    try {
      const iceCandidate = new RTCIceCandidate(candidate.data);
      if (!this.connection) {
        throw new Error(
          "Received new remote candidate but RTCConnection is undefined"
        );
      }
      this.connection.addIceCandidate(iceCandidate);
    } catch (error) {
      console.error(error);
    }
  };

  private onLocalCandidate = () => {
    return (event: RTCPeerConnectionIceEvent) => {
      if (event.candidate) {
        this.onSendMediaEvent({
          type: "candidate",
          key: this.key,
          data: {
            candidate: event.candidate.candidate,
            sdpMLineIndex: event.candidate.sdpMLineIndex,
          },
        });
      }
    };
  };

  private onTrack = () => {
    return (event: RTCTrackEvent) => {
      const [stream] = event.streams;
      const mid = event.transceiver.mid!;

      const peer = this.midToPeer.get(mid)!;
      const isScreenSharing = mid.includes("SCREEN") || false;

      this.midToStream.set(mid, stream);

      stream.onremovetrack = (e) => {
        const hasTracks = stream.getTracks().length > 0;

        if (!hasTracks) {
          this.midToStream.delete(mid);
          stream.onremovetrack = null;
        }

        this.callbacks.onTrackRemoved?.({
          peer,
          track: e.track,
          stream,
          mid: event.transceiver.mid!,
          metadata: this.midToTrackMetadata.get(mid),
        });
      };

      this.callbacks.onTrackAdded?.({
        track: event.track,
        peer,
        stream,
        mid: event.transceiver.mid!,
        metadata: this.midToTrackMetadata.get(mid),
      });
    };
  };

  private onPeerJoined = (peer: Peer) => {
    this.addPeer(peer);
    this.callbacks.onPeerJoined?.(peer);
  };

  private onPeerLeft = (peerId: String) => {
    const peer = this.idToPeer.get(peerId);
    if (peer) {
      this.removePeer(peer);
      this.callbacks.onPeerLeft?.(peer);
    }
  };

  private onSendMediaEvent = (mediaEvent: MediaEvent): void => {
    this.callbacks.onSendSerializedMediaEvent(serializeMediaEvent(mediaEvent));
  };

  private onSendMediaEventResult = (mediaEvent: MediaEvent): Promise<any> => {
    return this.callbacks.onSendSerializedMediaEventResult(
      serializeMediaEvent(mediaEvent)
    );
  };

  private addPeer = (peer: Peer): void => {
    peer.midToTrackMetadata.forEach((metadata, mid, map) => {
      this.midToPeer.set(mid, peer);
      this.midToTrackMetadata.set(mid, metadata);
    });
    this.idToPeer.set(peer.id, peer);
  };

  private removePeer = (peer: Peer): void => {
    peer.midToTrackMetadata.forEach((metadata, mid, map) => {
      this.midToPeer.delete(mid);
      this.midToTrackMetadata.delete(mid);
    });
    this.idToPeer.delete(peer.id);
  };
}
