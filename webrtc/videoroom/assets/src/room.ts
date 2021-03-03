import { Channel, Socket } from "phoenix";

const RTC_CONFIG: RTCConfiguration = {
  // iceServers: [
  //     YOUR TURN AND STUN SERVERS
  // ]
};

const CONSTRAINTS = {
  audio: true,
  video: { width: 1280, height: 720 },
};

const DEFAULT_ERROR_MESSAGE =
  "Cannot connect to the server, try again by refreshing the page";

interface OfferData {
  data: RTCSessionDescriptionInit;
}

interface CandidateData {
  data: RTCIceCandidateInit;
}

interface RoomCallbacks {
  onConnectionError?: (message: string) => void;
  onAddStream?: (stream: MediaStream, mute: boolean) => void;
  onRemoveStream?: (stream: MediaStream) => void;
}

export class Room {
  private readonly socket: Socket;
  private channel?: Channel;

  private localStream?: MediaStream;
  private remoteStreams: Set<MediaStream> = new Set<MediaStream>();
  private connection?: RTCPeerConnection;

  private callbacks?: RoomCallbacks;

  constructor(socket: Socket, roomId: string, callbacks?: RoomCallbacks) {
    this.socket = socket;
    this.callbacks = callbacks;

    const handleError = () => {
      this.callbacks?.onConnectionError?.(DEFAULT_ERROR_MESSAGE);
      this.stop();
    };

    socket.onError(handleError);
    socket.onClose(handleError);

    this.setup(roomId);
  }

  private setup = async (roomId: string) => {
    try {
      this.localStream = await navigator.mediaDevices.getUserMedia(CONSTRAINTS);

      this.callbacks?.onAddStream?.(this.localStream, true);

      this.prepareChannel(roomId);
    } catch (error) {
      console.error(error);
    }
  };

  private prepareChannel = (roomId: string) => {
    this.channel = this.socket.channel(`room:${roomId}`, {});

    this.channel.on("offer", this.onOffer);
    this.channel.on("candidate", this.onCandidate);
    this.channel.on("error", (data) => {
      this.callbacks?.onConnectionError?.(data.error);
      this.stop();
    });

    this.channel
      .join()
      .receive("ok", (_) => this.start())
      .receive("error", (_) =>
        this.callbacks?.onConnectionError?.(
          "Unable to connect with backend service"
        )
      );
  };

  private start = () => {
    this.channel?.push("start", {});
  };

  private stop = () => {
    this.channel?.push("stop", {});
    this.channel?.leave();
  };

  private onOffer = async (offer: OfferData) => {
    if (!this.connection) {
      this.connection = new RTCPeerConnection(RTC_CONFIG);
      this.connection.onicecandidate = this.onIceCandidate();
      this.connection.ontrack = this.onTrack();

      this.localStream
        ?.getTracks()
        .forEach((track) => this.connection?.addTrack(track));
    } else {
      this.connection.createOffer({ iceRestart: true });
    }

    try {
      await this.connection.setRemoteDescription(offer.data);
      const answer = await this.connection.createAnswer();
      await this.connection.setLocalDescription(answer);

      this.channel?.push("answer", { data: answer });
    } catch (error) {
      console.error(error);
    }
  };

  private onCandidate = (candidate: CandidateData) => {
    try {
      const iceCandidate = new RTCIceCandidate(candidate.data);
      this.connection?.addIceCandidate(iceCandidate);
    } catch (error) {
      console.error(error);
    }
  };

  private onIceCandidate = () => {
    return (event: RTCPeerConnectionIceEvent) => {
      if (event.candidate) {
        this.channel?.push("candidate", { data: event.candidate });
      }
    };
  };

  private onTrack = () => {
    return (event: RTCTrackEvent) => {
      const [stream] = event.streams;

      stream.onremovetrack = (event) => {
        if (stream.getTracks().length === 0) {
          stream.onremovetrack = null;
          this.callbacks?.onRemoveStream?.(stream);
          this.remoteStreams.delete(stream);
        }
      };

      if (!this.remoteStreams.has(stream)) {
        this.callbacks?.onAddStream?.(stream, false);
        this.remoteStreams.add(stream);
      }
    };
  };
}
