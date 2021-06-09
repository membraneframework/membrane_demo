import { Channel, Push, Socket } from "phoenix";

import {
  MembraneWebRTC,
  isScreenSharingParticipant,
  MembraneWebRTCConfig,
} from "./membraneWebRTC";

const phoenix_channel_push_result = async (push: Push): Promise<any> => {
  return new Promise((resolve, reject) => {
    push
      .receive("ok", (response: any) => resolve(response))
      .receive("error", (response: any) => reject(response));
  });
};

export class MembraneWebRTCWrapper {
  private webRTC?: MembraneWebRTC;
  private socket: Socket;
  private channel?: Channel;
  private channelId: string;
  private socketRefs: string[] = [];
  private userId?: string;
  private webRTCConfig: MembraneWebRTCConfig;
  private localStreams: Set<MediaStream> = new Set<MediaStream>();

  constructor(socket: Socket, roomId: string, config: MembraneWebRTCConfig) {
    const { type = "participant" } = config;
    this.channelId =
      type === "participant"
        ? `room:${roomId}`
        : `room:screensharing:${roomId}`;
    this.socket = socket;
    this.webRTCConfig = config;

    const handleError = () => {
      this.webRTC?.handleError();
    };

    this.socketRefs.push(socket.onError(handleError));
    this.socketRefs.push(socket.onClose(handleError));
  }

  public join = async () => {
    const channel = this.socket.channel(this.channelId);
    this.channel = channel;

    const webRTCTransport = {
      push: (event: string, payload: Object) => channel.push(event, payload),
      pushResult: async (event: string, payload: Object) =>
        phoenix_channel_push_result(channel.push(event, payload)),
    };

    const webRTC = new MembraneWebRTC(webRTCTransport, this.webRTCConfig);
    this.webRTC = webRTC;
    this.webRTC.getCallbacks().forEach(({ event, callback }) => {
      channel.on(event, (data) => {
        callback(data);
      });
    });

    this.channel.on("membraneWebRTCEvent", webRTC.receiveEvent);

    const { userId } = await phoenix_channel_push_result(this.channel.join());
    this.userId = userId;
    this.webRTC.setUserId(userId);
    this.localStreams.forEach((stream) => this.webRTC?.addLocalStream(stream));
    this.webRTC.join();
  };

  public leave = () => {
    this.webRTC?.leave();
    this.channel?.leave();
    this.socket.off(this.socketRefs);
  };

  public addLocalStream = (stream: MediaStream) => {
    this.localStreams.add(stream);
  };

  public toggleVideo = () => {
    this.webRTC?.toggleVideo();
  };

  public toggleAudio = () => {
    this.webRTC?.toggleAudio();
  };
}
