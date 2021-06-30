import { Channel, Push } from "phoenix";

import { SerializedMediaEvent } from "./membraneWebRTC";

export const phoenixChannelPushResult = async (push: Push): Promise<any> => {
  return new Promise((resolve, reject) => {
    push
      .receive("ok", (response: any) => resolve(response))
      .receive("error", (response: any) => reject(response));
  });
};

export function getChannelId(roomId: string) {
  return `room:${roomId}`;
}

export function getMediaCallbacksFromPhoenixChannel(channel: Channel) {
  return {
    onSendSerializedMediaEvent: (serializedMediaEvent: SerializedMediaEvent) =>
      channel.push("mediaEvent", { data: serializedMediaEvent }),
    onSendSerializedMediaEventResult: async (
      serializedMediaEvent: SerializedMediaEvent
    ) =>
      phoenixChannelPushResult(
        channel.push("mediaEvent", { data: serializedMediaEvent })
      ),
  };
}
