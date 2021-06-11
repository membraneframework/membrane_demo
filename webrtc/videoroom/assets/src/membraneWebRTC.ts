const DEFAULT_ERROR_MESSAGE =
  "Cannot connect to the server, try again by refreshing the page";

export interface MediaEvent {
  type: string;
  payload: Object;
}

export interface MediaCallbacks {
  push: (mediaEvent: MediaEvent) => void;
  pushResult: (mediaEvent: MediaEvent) => Promise<any>;
}

interface Peer {
  id: string;
  displayName: string;
  mutedAudio: boolean;
  mutedVideo: boolean;
  mids: string[];
}

interface OfferData {
  data: RTCSessionDescriptionInit;
}

interface CandidateData {
  data: RTCIceCandidateInit;
}

interface TrackContext {
  track: MediaStreamTrack;
  stream: MediaStream;
  peer: Peer;
  label?: string;
  mutedAudio?: boolean;
  mutedVideo?: boolean;
  isScreenSharing: boolean;
}

interface PeerContext {
  peer: Peer;
  allPeers: Peer[];
  isLocalPeer?: boolean;
  userId?: string;
}

interface PeerConfig {
  displayName: string;
  relayVideo: boolean;
  relayAudio: boolean;
}

interface Callbacks {
  onJoin?: () => void;
  onLeave?: () => void;
  onAddTrack?: (ctx: TrackContext) => void;
  onRemoveTrack?: (ctx: TrackContext) => void;
  onConnectionError?: (message: string) => void;
  onPeerToggledVideo?: (ctx: PeerContext) => void;
  onPeerToggledAudio?: (ctx: PeerContext) => void;
  onPeerJoined?: (ctx: PeerContext) => void;
  onPeerLeft?: (ctx: PeerContext) => void;
}

export interface MembraneWebRTCConfig {
  callbacks?: Callbacks;
  rtcConfig?: RTCConfiguration;
  type?: "participant" | "screensharing";
  peerConfig: PeerConfig;
}

export function isScreenSharingPeer(peer: Peer): boolean {
  return peer.mids.find((mid) => mid.includes("SCREEN")) !== undefined;
}

export class MembraneWebRTC {
  private peerConfig: PeerConfig;
  private displayName: string;
  private type: "participant" | "screensharing";

  private mediaCallbacks: MediaCallbacks;

  private localStreams: Set<MediaStream> = new Set<MediaStream>();
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
  private userId?: string;

  private readonly callbacks: Callbacks;

  constructor(mediaCallbacks: MediaCallbacks, config: MembraneWebRTCConfig) {
    const { type = "participant", callbacks, rtcConfig, peerConfig } = config;

    this.displayName = peerConfig.displayName;
    this.peerConfig = peerConfig;
    this.type = type;
    this.mediaCallbacks = mediaCallbacks;

    this.callbacks = callbacks || {};
    this.rtcConfig = rtcConfig || this.rtcConfig;
  }

  public receiveEvent = (data: any) => {
    switch (data.type) {
      case "offer":
        this.onOffer(data);
        break;

      case "candidate":
        this.onRemoteCandidate(data);
        break;

      case "toggledVideo":
        this.callbacks.onPeerToggledVideo?.(
          this.getPeerContext(data.data.peerId)
        );
        break;

      case "toggledAudio":
        this.callbacks.onPeerToggledAudio?.(
          this.getPeerContext(data.data.peerId)
        );
        break;

      case "peerJoined":
        const peer = data.data.peer;
        this.onPeerJoined(peer, peer.id === this.userId);
        break;

      case "peerLeft":
        this.onPeerLeft(data.data.peerId);
        break;

      case "error":
        this.callbacks.onConnectionError?.(data.error);
        this.leave();
        break;
    }
  };

  public handleError = () => {
    this.callbacks.onConnectionError?.(DEFAULT_ERROR_MESSAGE);
    this.leave();
  };

  public addLocalStream = (stream: MediaStream) => {
    if (this.connection) {
      throw new Error(
        "Adding streams when connection is established is not yet supported"
      );
    }
    this.localStreams.add(stream);
  };

  public join = async () => {
    try {
      const payload = { ...this.peerConfig, type: this.type };

      const { peers } = await this.mediaCallbacks.pushResult({
        type: "start",
        payload,
      });

      (peers as Array<Peer>).forEach((p) =>
        this.onPeerJoined(p, p.id === this.userId)
      );

      this.callbacks.onJoin?.();
    } catch (e) {
      this.callbacks.onConnectionError?.(e);
      this.leave();
    }
  };

  public setUserId = (userId: string) => {
    this.userId = userId;
  };

  public toggleVideo = () => {
    this.mediaCallbacks.push({ type: "toggledVideo", payload: {} });
  };

  public toggleAudio = () => {
    this.mediaCallbacks.push({ type: "toggledAudio", payload: {} });
  };

  public leave = () => {
    this.mediaCallbacks.push({ type: "stop", payload: {} });

    if (this.connection) {
      this.connection.onicecandidate = null;
      this.connection.ontrack = null;
    }
    this.localStreams.forEach((stream) =>
      stream.getTracks().forEach((track) => track.stop())
    );
    this.connection = undefined;

    this.callbacks.onLeave?.();
  };

  private getPeerContext = (peerId: string): PeerContext => {
    return {
      peer: this.idToPeer.get(peerId)!,
      allPeers: Array.from(this.idToPeer.values()),
      isLocalPeer: peerId === this.userId,
      userId: this.userId,
    };
  };

  private onOffer = async (offer: OfferData) => {
    if (!this.connection) {
      this.connection = new RTCPeerConnection(this.rtcConfig);
      this.connection.onicecandidate = this.onLocalCandidate();
      this.connection.ontrack = this.onTrack();

      this.localStreams.forEach((stream) => {
        stream.getTracks().forEach((track) => {
          this.connection!.addTrack(track, stream);
        });
      });
    } else {
      this.connection.createOffer({ iceRestart: true });
    }

    try {
      await this.connection.setRemoteDescription(offer.data);
      const answer = await this.connection.createAnswer();
      await this.connection.setLocalDescription(answer);

      this.mediaCallbacks.push({
        type: "answer",
        payload: answer,
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
        this.mediaCallbacks.push({
          type: "candidate",
          payload: event.candidate,
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

      stream.onremovetrack = (event) => {
        const hasTracks = stream.getTracks().length > 0;

        if (!hasTracks) {
          this.midToStream.delete(mid);
          stream.onremovetrack = null;
        }

        this.callbacks.onRemoveTrack?.({
          peer,
          track: event.track,
          stream,
          isScreenSharing,
        });
      };

      const label = peer?.displayName || "";
      const mutedVideo = peer?.mutedVideo;
      const mutedAudio = peer?.mutedAudio;

      this.callbacks.onAddTrack?.({
        track: event.track,
        peer,
        label,
        stream,
        isScreenSharing,
        mutedVideo,
        mutedAudio,
      });
    };
  };

  private onPeerJoined = (peer: Peer, isLocalPeer: boolean = false) => {
    this.idToPeer.set(peer.id, peer);
    peer.mids.forEach((mid) => this.midToPeer.set(mid, peer));

    this.callbacks.onPeerJoined?.({
      peer,
      isLocalPeer,
      allPeers: Array.from(this.idToPeer.values()),
      userId: this.userId,
    });
  };

  private onPeerLeft = (peerId: String) => {
    const peer = this.idToPeer.get(peerId);
    this.idToPeer.delete(peerId);
    if (peer) {
      peer.mids.forEach((mid) => this.midToPeer.delete(mid));
      this.callbacks.onPeerLeft?.({
        peer,
        allPeers: Array.from(this.idToPeer.values()),
      });
    }
  };
}
