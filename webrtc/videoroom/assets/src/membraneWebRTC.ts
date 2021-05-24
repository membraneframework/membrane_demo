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

interface SignalingOptions {
  displayName: string;
  relayVideo: boolean;
  relayAudio: boolean;
}

interface Callbacks {
  onAddTrack?: (ctx: TrackContext) => void;
  onRemoveTrack?: (ctx: TrackContext) => void;
  onConnectionError?: (message: string) => void;
  onReplaceStream?: (
    oldStream: MediaStream,
    newStream: MediaStream,
    newLabel: string
  ) => void;
  onDisplayStream?: (stream: MediaStream, label: string) => void;
  onDisplayTrack?: (ctx: TrackContext) => void;
  onHideTrack?: (ctx: TrackContext) => void;
  onParticipantToggledVideo?: (participantId: string) => void;
  onParticipantToggledAudio?: (participantId: string) => void;
  onOfferData?: (data: OfferData) => void;
  onNoMediaParticipantArrival?: (participant: Participant) => void;
  onNoMediaParticipantLeave?: (participant: Participant) => void;
  onParticipantsList?: (participants: Participant[]) => void;
}

interface MembraneWebRTCConfig {
  callbacks?: Callbacks;
  rtcConfig?: RTCConfiguration;
  type?: "participant" | "screensharing";
  signalingOptions: SignalingOptions;
}

export class MembraneWebRTC {
  private readonly socket: Socket;
  private _channel?: Channel;
  private channelId: string;
  private socketRefs: string[] = [];
  private signalingOptions: SignalingOptions;
  private displayName: string;

  private maxDisplayNum: number = 1;
  private localTracksMapping: Map<
    String,
    [MediaStreamTrack, MediaStream]
  > = new Map();
  private screensharingStream?: MediaStream;
  private remoteStreams: Set<MediaStream> = new Set<MediaStream>();
  private midToStream: Map<String, MediaStream> = new Map();
  private connection?: RTCPeerConnection;
  private participants: Participant[] = [];
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
      signalingOptions,
    } = config;

    this.socket = socket;
    this.displayName = signalingOptions.displayName;
    this.signalingOptions = signalingOptions;
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

  public addTrack = (track: MediaStreamTrack, stream: MediaStream) => {
    if (this.connection) {
      throw new Error(
        "Adding tracks when connection is established is not yet supported"
      );
    }
    this.localTracksMapping.set(track.id, [track, stream]);
  };

  public start = async () => {
    this.channel = this.socket.channel(this.channelId, this.signalingOptions);

    this.channel.on("offer", this.onOffer);
    this.channel.on("candidate", this.onRemoteCandidate);
    this.channel.on("replaceTrack", (data: any) => {
      const oldTrackId = data.data.oldTrackId;
      const newTrackId = data.data.newTrackId;
      const oldStream = this.midToStream.get(oldTrackId)!;
      const newStream = this.midToStream.get(newTrackId)!;
      const oldTrack = oldStream.getVideoTracks()[0];
      const newTrack = newStream.getVideoTracks()[0];
      const oldParticipant = this.midToParticipant.get(oldTrackId);
      const newParticipant = this.midToParticipant.get(newTrackId);

      if (oldParticipant) {
        const oldCtx = {
          track: oldTrack,
          stream: oldStream,
          participant: oldParticipant,
          label: oldParticipant?.displayName ?? "",
          isScreenSharing:
            oldParticipant?.mids
              .find((mid) => mid === oldTrackId)
              ?.includes("SCREEN") || false,
        };
        this.callbacks.onHideTrack?.(oldCtx);
      }

      if (newParticipant) {
        const newCtx = {
          track: newTrack,
          stream: newStream,
          participant: newParticipant,
          label: newParticipant?.displayName ?? "",
          isScreenSharing:
            newParticipant?.mids
              .find((mid) => mid === newTrackId)
              ?.includes("SCREEN") || false,
        };
        this.callbacks.onDisplayTrack?.(newCtx);
      }
    });
    this.channel.on("displayTrack", (data: any) => {
      const trackId = data.data.trackId;
      const stream = this.midToStream.get(trackId)!;
      const track = stream.getVideoTracks()[0];
      const participant = this.participants.find(({ mids }) =>
        mids.includes(trackId)
      );

      if (participant) {
        this.callbacks.onDisplayTrack?.({
          track,
          stream,
          participant,
          label: participant?.displayName ?? "",
          isScreenSharing:
            participant?.mids
              .find((mid) => mid === trackId)
              ?.includes("SCREEN") || false,
        });
      }
    });
    this.channel.on("participantsList", (data: any) => {
      this.executeCallbacksForNoMediaParticipants(
        data.participants,
        this.participants
      );
      this.participants = data.participants;
      this.participants.forEach((p) =>
        p.mids.forEach((mid) => this.midToParticipant.set(mid, p))
      );
      this.callbacks.onParticipantsList?.(this.participants);
    });

    this.channel.on("toggledVideo", (data: any) => {
      this.callbacks.onParticipantToggledVideo?.(data.data.participantId);
    });

    this.channel.on("toggledAudio", (data: any) => {
      this.callbacks.onParticipantToggledAudio?.(data.data.participantId);
    });

    this.channel.on("error", (data: any) => {
      this.callbacks.onConnectionError?.(data.error);
      this.stop();
    });

    await phoenix_channel_push_result(this.channel.join());

    try {
      const { maxDisplayNum } = await phoenix_channel_push_result(
        this.channel.push("start", {})
      );
      this.maxDisplayNum = maxDisplayNum;
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
    this.remoteStreams = new Set<MediaStream>();
    if (this.connection) {
      this.connection.onicecandidate = null;
      this.connection.ontrack = null;
    }
    this.localTracksMapping.forEach(([track, _stream], _trackId) =>
      track.stop()
    );
    this.connection = undefined;
    this.socket.off(this.socketRefs);
  };

  private onOffer = async (offer: OfferData) => {
    this.userId = offer.userId;
    this.executeCallbacksForNoMediaParticipants(
      offer.participants,
      this.participants
    );
    this.participants = offer.participants;

    this.midToParticipant = new Map<String, Participant>();
    this.participants.forEach((p) =>
      p.mids.forEach((mid) => this.midToParticipant.set(mid, p))
    );

    this.callbacks.onOfferData?.(offer);

    if (!this.connection) {
      this.connection = new RTCPeerConnection(this.rtcConfig);
      this.connection.onicecandidate = this.onLocalCandidate();
      this.connection.ontrack = this.onTrack();
      this.localTracksMapping.forEach(([track, stream], _trackId) => {
        this.connection!.addTrack(track, stream);
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

  private executeCallbacksForNoMediaParticipants = (
    newParticipants: Participant[],
    oldParticipants: Participant[]
  ) => {
    const oldParticipantsIds = new Set(oldParticipants.map((p) => p.id));
    const newParticipantsIds = new Set(newParticipants.map((p) => p.id));

    oldParticipants
      .filter(
        (p) =>
          p.mids.length == 0 &&
          !newParticipantsIds.has(p.id) &&
          p.id != this.userId
      )
      .forEach((p) => this.callbacks.onNoMediaParticipantLeave?.(p));
    newParticipants
      .filter(
        (p) =>
          p.mids.length == 0 &&
          !oldParticipantsIds.has(p.id) &&
          p.id != this.userId
      )
      .forEach((p) => this.callbacks.onNoMediaParticipantArrival?.(p));
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

      if (isScreenSharing) {
        this.screensharingStream = stream;
      } else {
        this.remoteStreams.add(stream);
      }
      this.midToStream.set(mid, stream);

      stream.onremovetrack = (event) => {
        const hasTracks = stream.getTracks().length > 0;

        if (!hasTracks) {
          if (isScreenSharing) {
            this.screensharingStream = undefined;
          } else {
            this.remoteStreams.delete(stream);
          }
          this.midToStream.delete(mid);
          stream.onremovetrack = null;
        }

        this.callbacks.onRemoveTrack?.({
          track: event.track,
          participant,
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

      if (this.remoteStreams.size <= this.maxDisplayNum && !isScreenSharing) {
        this.callbacks.onDisplayTrack?.({
          track: event.track,
          participant,
          label,
          stream,
          isScreenSharing,
        });
      }
    };
  };
}
