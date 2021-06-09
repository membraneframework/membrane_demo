export const DEFAULT_ERROR_MESSAGE =
  "Cannot connect to the server, try again by refreshing the page";

interface MembraneWebRTCTransport {
  push: (event: string, payload: Object) => void;
  pushResult: (event: string, payload: Object) => Promise<any>;
}

interface MembraneWebRTCCallback {
  event: string;
  callback: (data: any) => void;
}

interface Participant {
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
  participant: Participant;
  label?: string;
  mutedAudio?: boolean;
  mutedVideo?: boolean;
  isScreenSharing: boolean;
}

interface ParticipantContext {
  participant: Participant;
  allParticipants: Participant[];
  isLocalParticipant?: boolean;
}

interface ParticipantConfig {
  displayName: string;
  relayVideo: boolean;
  relayAudio: boolean;
}

interface Callbacks {
  onAddTrack?: (ctx: TrackContext) => void;
  onRemoveTrack?: (ctx: TrackContext) => void;
  onConnectionError?: (message: string) => void;
  onDisplayParticipant?: (participantId: string) => void;
  onHideParticipant?: (participantId: string) => void;
  onParticipantToggledVideo?: (participantId: string) => void;
  onParticipantToggledAudio?: (participantId: string) => void;
  onParticipantJoined?: (ctx: ParticipantContext) => void;
  onParticipantLeft?: (ctx: ParticipantContext) => void;
}

export interface MembraneWebRTCConfig {
  callbacks?: Callbacks;
  rtcConfig?: RTCConfiguration;
  type?: "participant" | "screensharing";
  participantConfig: ParticipantConfig;
}

export function isScreenSharingParticipant(participant: Participant): boolean {
  return participant.mids.find((mid) => mid.includes("SCREEN")) !== undefined;
}

export class MembraneWebRTC {
  private participantConfig: ParticipantConfig;
  private displayName: string;
  private type: "participant" | "screensharing";

  private transport: MembraneWebRTCTransport;

  private maxDisplayNum: number = 1;
  private localStreams: Set<MediaStream> = new Set<MediaStream>();
  private midToStream: Map<String, MediaStream> = new Map();
  private connection?: RTCPeerConnection;
  private idToParticipant: Map<String, Participant> = new Map();
  private midToParticipant: Map<String, Participant> = new Map<
    String,
    Participant
  >();
  private readonly rtcConfig: RTCConfiguration = {
    iceServers: [
      {
        urls: "stun:stun.l.google.com:19302",
      },
    ],
  };
  private userId?: string;

  private readonly callbacks: Callbacks;

  constructor(
    transport: MembraneWebRTCTransport,
    config: MembraneWebRTCConfig
  ) {
    const {
      type = "participant",
      callbacks,
      rtcConfig,
      participantConfig,
    } = config;

    this.displayName = participantConfig.displayName;
    this.participantConfig = participantConfig;
    this.type = type;
    this.transport = transport;

    this.callbacks = callbacks || {};
    this.rtcConfig = rtcConfig || this.rtcConfig;
  }

  public getCallbacks = (): MembraneWebRTCCallback[] => [
    { event: "offer", callback: this.onOffer },
    { event: "candidate", callback: this.onRemoteCandidate },
    { event: "replaceParticipant", callback: this.replaceParticipant },
    {
      event: "displayParticipant",
      callback: (data: any) =>
        this.callbacks.onDisplayParticipant?.(data.data.participantId),
    },
    {
      event: "toggledVideo",
      callback: (data: any) =>
        this.callbacks.onParticipantToggledVideo?.(data.data.participantId),
    },
    {
      event: "toggledAudio",
      callback: (data: any) =>
        this.callbacks.onParticipantToggledAudio?.(data.data.participantId),
    },
    {
      event: "participantJoined",
      callback: (data: any) => {
        const participant = data.data.participant;
        this.onParticipantJoined(participant, participant.id === this.userId);
      },
    },
    {
      event: "participantLeft",
      callback: (data: any) => this.onParticipantLeft(data.data.participantId),
    },
    {
      event: "error",
      callback: (data: any) => {
        this.callbacks.onConnectionError?.(data.error);
        this.leave();
      },
    },
  ];

  public receiveEvent = (data: any) => {
    switch (data.type) {
      case "offer":
        this.onOffer(data);
        break;

      case "candidate":
        this.onRemoteCandidate(data);
        break;

      case "replaceParticipant":
        this.replaceParticipant(data);
        break;

      case "displayParticipant":
        this.callbacks.onDisplayParticipant?.(data.data.participantId);
        break;

      case "toggledVideo":
        this.callbacks.onParticipantToggledVideo?.(data.data.participantId);
        break;

      case "toggledAudio":
        this.callbacks.onParticipantToggledAudio?.(data.data.participantId);
        break;

      case "participantJoined":
        this.callbacks.onParticipantToggledAudio?.(data.data.participantId);
        break;

      case "participantLeft":
        this.onParticipantLeft(data.data.participantId);
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
      const payload = { ...this.participantConfig, type: this.type };

      const { maxDisplayNum, participants } = await this.transport.pushResult(
        "start",
        payload
      );

      this.maxDisplayNum = maxDisplayNum;

      (participants as Array<Participant>).forEach((p) =>
        this.onParticipantJoined(p, p.id === this.userId)
      );
    } catch (e) {
      this.callbacks.onConnectionError?.(e);
      this.leave();
    }
  };

  public setUserId = (userId: string) => {
    this.userId = userId;
  };

  public toggleVideo = () => {
    this.transport.push("toggledVideo", {});
  };

  public toggleAudio = () => {
    this.transport.push("toggledAudio", {});
  };

  public leave = () => {
    this.transport.push("stop", {});

    if (this.connection) {
      this.connection.onicecandidate = null;
      this.connection.ontrack = null;
    }
    this.localStreams.forEach((stream) =>
      stream.getTracks().forEach((track) => track.stop())
    );
    this.connection = undefined;
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

      this.transport.push("answer", { data: answer });
      // this.channel.push("answer", { data: answer });
    } catch (error) {
      console.error(error);
    }
  };

  private replaceParticipant = (data: any) => {
    const oldParticipantId = data.data.oldParticipantId;
    const newParticipantId = data.data.newParticipantId;

    this.callbacks.onHideParticipant?.(oldParticipantId);
    this.callbacks.onDisplayParticipant?.(newParticipantId);
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
        this.transport.push("candidate", { data: event.candidate });
      }
    };
  };

  private onTrack = () => {
    return (event: RTCTrackEvent) => {
      const [stream] = event.streams;
      const mid = event.transceiver.mid!;
      const participant = this.midToParticipant.get(mid)!;
      const isScreenSharing = mid.includes("SCREEN") || false;

      this.midToStream.set(mid, stream);

      stream.onremovetrack = (event) => {
        const hasTracks = stream.getTracks().length > 0;

        if (!hasTracks) {
          this.midToStream.delete(mid);
          stream.onremovetrack = null;
        }

        this.callbacks.onRemoveTrack?.({
          participant,
          track: event.track,
          stream,
          isScreenSharing,
        });
      };

      const label = participant?.displayName || "";
      const mutedVideo = participant?.mutedVideo;
      const mutedAudio = participant?.mutedAudio;

      this.callbacks.onAddTrack?.({
        track: event.track,
        participant,
        label,
        stream,
        isScreenSharing,
        mutedVideo,
        mutedAudio,
      });
    };
  };

  private onParticipantJoined = (
    participant: Participant,
    isLocalParticipant: boolean = false
  ) => {
    this.idToParticipant.set(participant.id, participant);
    participant.mids.forEach((mid) =>
      this.midToParticipant.set(mid, participant)
    );

    this.callbacks.onParticipantJoined?.({
      participant,
      isLocalParticipant,
      allParticipants: Array.from(this.idToParticipant.values()),
    });

    if (
      !isLocalParticipant &&
      !isScreenSharingParticipant(participant) &&
      Array.from(this.idToParticipant.values()).filter(
        (p) => !isScreenSharingParticipant(p) && p.id !== this.userId
      ).length <= this.maxDisplayNum
    ) {
      this.callbacks.onDisplayParticipant?.(participant.id);
    }
  };

  private onParticipantLeft = (participantId: String) => {
    const participant = this.idToParticipant.get(participantId);
    this.idToParticipant.delete(participantId);
    if (participant) {
      participant.mids.forEach((mid) => this.midToParticipant.delete(mid));
      this.callbacks.onParticipantLeft?.({
        participant,
        allParticipants: Array.from(this.idToParticipant.values()),
      });
    }
  };
}
