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
  displayName: string;
  mids: string[];
}

interface OfferData {
  data: RTCSessionDescriptionInit;
  participants: Participant[];
}

interface CandidateData {
  data: RTCIceCandidateInit;
}

interface TrackContext {
  track: MediaStreamTrack;
  stream: MediaStream;
  label?: string;
  isScreenSharing: boolean;
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
}

interface MembraneWebRTCConfig {
  callbacks?: Callbacks;
  rtcConfig?: RTCConfiguration;
  type?: "participant" | "screensharing";
  displayName: string;
}

export class MembraneWebRTC {
  private readonly socket: Socket;
  private _channel?: Channel;
  private channelId: string;
  private socketRefs: string[] = [];
  private displayName: string;

  private maxDisplayNum: number = 1;
  private localTracks: Set<MediaStreamTrack> = new Set<MediaStreamTrack>();
  private localStream?: MediaStream;
  private screensharingStream?: MediaStream;
  private remoteStreams: Set<MediaStream> = new Set<MediaStream>();
  private midToStream: Map<String, MediaStream> = new Map();
  private connection?: RTCPeerConnection;
  private participants: Participant[] = [];
  private readonly rtcConfig: RTCConfiguration = {
    iceServers: [
      {
        urls: "stun:stun.l.google.com:19302",
      },
    ],
  };

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
    const { type = "participant", callbacks, rtcConfig, displayName } = config;

    this.socket = socket;
    this.displayName = displayName;
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
    this.localTracks.add(track);
    this.localStream = stream;
  };

  public start = async () => {
    this.channel = this.socket.channel(this.channelId, {
      displayName: this.displayName,
    });

    this.channel.on("offer", this.onOffer);
    this.channel.on("candidate", this.onRemoteCandidate);
    this.channel.on("replaceTrack", (data: any) => {
      const oldTrackId = data.data.oldTrackId;
      const newTrackId = data.data.newTrackId;
      const oldStream = this.midToStream.get(oldTrackId)!;
      const newStream = this.midToStream.get(newTrackId)!;
      const oldTrack = oldStream.getVideoTracks()[0];
      const newTrack = newStream.getVideoTracks()[0];
      const oldParticipant = this.participants.find(({ mids }) =>
        mids.includes(oldTrackId)
      );
      const newParticipant = this.participants.find(({ mids }) =>
        mids.includes(newTrackId)
      );
      const oldCtx = {
        track: oldTrack,
        stream: oldStream,
        label: oldParticipant?.displayName ?? "",
        isScreenSharing:
          oldParticipant?.mids
            .find((mid) => mid === oldTrackId)
            ?.includes("SCREEN") || false,
      };
      const newCtx = {
        track: newTrack,
        stream: newStream,
        label: newParticipant?.displayName ?? "",
        isScreenSharing:
          newParticipant?.mids
            .find((mid) => mid === newTrackId)
            ?.includes("SCREEN") || false,
      };
      this.callbacks.onHideTrack?.(oldCtx);
      this.callbacks.onDisplayTrack?.(newCtx);
    });
    this.channel.on("displayTrack", (data: any) => {
      const trackId = data.data.trackId;
      const stream = this.midToStream.get(trackId)!;
      const track = stream.getVideoTracks()[0];
      const participant = this.participants.find(({ mids }) =>
        mids.includes(trackId)
      );

      this.callbacks.onDisplayTrack?.({
        track,
        stream,
        label: participant?.displayName ?? "",
        isScreenSharing:
          participant?.mids
            .find((mid) => mid === trackId)
            ?.includes("SCREEN") || false,
      });
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

  public stop = () => {
    this.channel.push("stop", {});
    this.channel.leave();
    this.remoteStreams = new Set<MediaStream>();
    if (this.connection) {
      this.connection.onicecandidate = null;
      this.connection.ontrack = null;
    }
    this.localTracks.forEach((t) => t.stop());
    this.connection = undefined;
    this.socket.off(this.socketRefs);
  };

  private onOffer = async (offer: OfferData) => {
    this.participants = offer.participants;

    if (!this.connection) {
      this.connection = new RTCPeerConnection(this.rtcConfig);
      this.connection.onicecandidate = this.onLocalCandidate();
      this.connection.ontrack = this.onTrack();
      this.localTracks.forEach((track) =>
        this.connection!.addTrack(track, this.localStream!)
      );
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
          stream,
          isScreenSharing,
        });
      };

      const label =
        this.participants.find((p) => p.mids.includes(mid))?.displayName || "";
      this.callbacks.onAddTrack?.({
        track: event.track,
        label,
        stream,
        isScreenSharing,
      });

      if (this.remoteStreams.size <= this.maxDisplayNum && !isScreenSharing) {
        this.callbacks.onDisplayTrack?.({
          track: event.track,
          label,
          stream,
          isScreenSharing,
        });
      }
    };
  };
}
