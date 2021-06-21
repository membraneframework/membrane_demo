import { Channel, Push } from "phoenix";

import { SerializedMediaEvent } from "./membraneWebRTC";

export const phoenixChannelPushResult = async (push: Push): Promise<any> => {
  return new Promise((resolve, reject) => {
    push
      .receive("ok", (response: any) => resolve(response))
      .receive("error", (response: any) => reject(response));
  });
};

export function getChannelId(
  type: "participant" | "screensharing",
  roomId: string
) {
  if (type === "participant") {
    return `room:${roomId}`;
  } else {
    return `room:screensharing:${roomId}`;
  }
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
