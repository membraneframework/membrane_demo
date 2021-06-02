import { Channel, Push, Socket } from "phoenix";

const DEFAULT_ERROR_MESSAGE =
  "Cannot connect to the server, try again by refreshing the page";

const phoenix_channel_push_result = async (push: Push): Promise<any> => {
  return new Promise((resolve, reject) => {
    push
      .receive("ok", (response: any) => resolve(response))
      .receive("error", (response: any) => reject(response));
  });
};

interface Participant {
  id: string;
  displayName: string;
  mutedAudio: boolean;
  mutedVideo: boolean;
  mids: string[];
}

interface OfferData {
  data: RTCSessionDescriptionInit;
  participants: Participant[];
  userId: string;
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

interface MembraneWebRTCConfig {
  callbacks?: Callbacks;
  rtcConfig?: RTCConfiguration;
  type?: "participant" | "screensharing";
  participantConfig: ParticipantConfig;
}

export function isScreenSharingParticipant(participant: Participant): boolean {
  return participant.mids.find((mid) => mid.includes("SCREEN")) !== undefined;
}

export class MembraneWebRTC {
  private readonly socket: Socket;
  private _channel?: Channel;
  private channelId: string;
  private socketRefs: string[] = [];
  private participantConfig: ParticipantConfig;
  private displayName: string;

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

  private get channel(): Channel {
    if (!this._channel) {
      throw new Error("Phoenix channel is not initialized");
    }
    return this._channel;
  }

  private set channel(ch: Channel) {
    this._channel = ch;
  }

  constructor(socket: Socket, roomId: string, config: MembraneWebRTCConfig) {
    const {
      type = "participant",
      callbacks,
      rtcConfig,
      participantConfig,
    } = config;

    this.socket = socket;
    this.displayName = participantConfig.displayName;
    this.participantConfig = participantConfig;
    this.channelId =
      type === "participant"
        ? `room:${roomId}`
        : `room:screensharing:${roomId}`;

    this.callbacks = callbacks || {};
    this.rtcConfig = rtcConfig || this.rtcConfig;

    const handleError = () => {
      this.callbacks.onConnectionError?.(DEFAULT_ERROR_MESSAGE);
      this.stop();
    };

    this.socketRefs.push(socket.onError(handleError));
    this.socketRefs.push(socket.onClose(handleError));
  }

  public addLocalStream = (stream: MediaStream) => {
    if (this.connection) {
      throw new Error(
        "Adding streams when connection is established is not yet supported"
      );
    }
    this.localStreams.add(stream);
  };

  public start = async () => {
    this.channel = this.socket.channel(this.channelId, this.participantConfig);

    this.channel.on("offer", this.onOffer);
    this.channel.on("candidate", this.onRemoteCandidate);
    this.channel.on("replaceParticipant", (data: any) => {
      const oldParticipantId = data.data.oldParticipantId;
      const newParticipantId = data.data.newParticipantId;

      this.callbacks.onHideParticipant?.(oldParticipantId);
      this.callbacks.onDisplayParticipant?.(newParticipantId);
    });

    this.channel.on("displayParticipant", (data: any) => {
      this.callbacks.onDisplayParticipant?.(data.data.participantId);
    });

    this.channel.on("toggledVideo", (data: any) => {
      this.callbacks.onParticipantToggledVideo?.(data.data.participantId);
    });

    this.channel.on("toggledAudio", (data: any) => {
      this.callbacks.onParticipantToggledAudio?.(data.data.participantId);
    });

    this.channel.on("participantJoined", (data: any) => {
      const participant = data.data.participant;
      this.onParticipantJoined(participant, participant.id === this.userId);
    });

    this.channel.on("participantLeft", (data: any) => {
      this.onParticipantLeft(data.data.participantId);
    });

    this.channel.on("error", (data: any) => {
      this.callbacks.onConnectionError?.(data.error);
      this.stop();
    });

    await phoenix_channel_push_result(this.channel.join());

    try {
      const {
        maxDisplayNum,
        userId,
        participants,
      } = await phoenix_channel_push_result(this.channel.push("start", {}));

      this.maxDisplayNum = maxDisplayNum;
      this.userId = userId;

      (participants as Array<Participant>).forEach((p) =>
        this.onParticipantJoined(p, p.id === userId)
      );
    } catch (e) {
      this.callbacks.onConnectionError?.(e);
      this.stop();
    }
  };

  public toggleVideo = () => {
    this.channel.push("toggledVideo", {});
  };

  public toggleAudio = () => {
    this.channel.push("toggledAudio", {});
  };

  public stop = () => {
    this.channel.push("stop", {});
    this.channel.leave();
    if (this.connection) {
      this.connection.onicecandidate = null;
      this.connection.ontrack = null;
    }
    this.localStreams.forEach((stream) =>
      stream.getTracks().forEach((track) => track.stop())
    );
    this.connection = undefined;
    this.socket.off(this.socketRefs);
  };

  private onOffer = async (offer: OfferData) => {
    this.userId = offer.userId;

    if (!this.connection) {
      this.connection = new RTCPeerConnection(this.rtcConfig);
      this.connection.onicecandidate = this.onLocalCandidate();
      this.connection.ontrack = this.onTrack();
      this.localStreams.forEach((stream) => {
        stream
          .getTracks()
          .forEach((track) => this.connection!.addTrack(track, stream));
      });
    } else {
      this.connection.createOffer({ iceRestart: true });
    }

    try {
      await this.connection.setRemoteDescription(offer.data);
      const answer = await this.connection.createAnswer();
      await this.connection.setLocalDescription(answer);

      this.channel.push("answer", { data: answer });
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
        this.channel.push("candidate", { data: event.candidate });
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
