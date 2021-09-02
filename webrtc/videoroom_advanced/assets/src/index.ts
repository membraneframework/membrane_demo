import { Room } from "./room";

const stunServers = parseStunServers(process.env.STUN_SERVERS);
const turnServers = parseTurnServers(process.env.TURN_SERVERS);
const iceServers = stunServers.concat(turnServers);

let room = new Room(iceServers);
room.init().then(() => room.join());

// stun_servers: "addr:port"
// turn_servers: "addr:port:username:password:proto"
// {
//     'url': 'stun:stun.l.google.com:19302'
// },
// {
//   'url': 'turn:192.158.29.39:3478?transport=udp',
//   'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
//   'username': '28224511:1379330808'
// },
// {
//   'url': 'turn:192.158.29.39:3478?transport=tcp',
//   'credential': 'JZEOEt2V3Qb0y27GRntt2u2PAYA=',
//   'username': '28224511:1379330808'
// }
function parseStunServers(stunServersRaw: String | undefined): RTCIceServer[] {
  if (stunServersRaw == undefined) {
    return [];
  }
  let rtcIceServers: RTCIceServer[] = [];
  let stunServers = stunServersRaw.split(",");
  for (let stunServer in stunServers) {
    let stunServerParts = stunServer.split(":");
    let rtcIceServer: RTCIceServer = {
      urls: "stun".concat(":", stunServerParts[0], ":", stunServerParts[1]),
    };
    rtcIceServers.push(rtcIceServer);
  }
  return rtcIceServers;
}

function parseTurnServers(turnServersRaw: String | undefined): RTCIceServer[] {
  console.log(turnServersRaw);
  if (turnServersRaw == undefined) {
    return [];
  }
  let rtcIceServers: RTCIceServer[] = [];
  let turnServers = turnServersRaw.split(",");
  for (let turnServer in turnServers) {
    let turnServerParts = turnServer.split(":");
    let rtcIceServer: RTCIceServer = {
      credential: turnServerParts[3],
      credentialType: "password",
      urls: "turn".concat(
        ":",
        turnServerParts[0],
        ":",
        turnServerParts[1],
        "?transport=",
        turnServerParts[4]
      ),
      username: turnServerParts[2],
    };
    rtcIceServers.push(rtcIceServer);
  }

  return rtcIceServers;
}
