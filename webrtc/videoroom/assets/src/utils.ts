import { Channel, Push } from "phoenix";

import { MediaEvent, MediaCallbacks } from "./membraneWebRTC";

export function createFakeVideoStream({
  width = 1,
  height = 1,
}: {
  width: number;
  height: number;
}): MediaStream {
  const canvas = document.createElement("canvas") as any;
  const ctx = canvas.getContext("2d");
  if (ctx) {
    ctx.fillStyle = "rgba(0,0,0,0)";
    ctx.fillRect(0, 0, width, height);
  }
  return canvas.captureStream(0);
}

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

export function getMediaCallbacksFromPhoenixChannel(
  channel: Channel
): MediaCallbacks {
  return {
    onSendMediaEvent: (event: MediaEvent) => channel.push("mediaEvent", event),
    onSendMediaEventResult: async (event: MediaEvent) =>
      phoenixChannelPushResult(channel.push("mediaEvent", event)),
  };
}
