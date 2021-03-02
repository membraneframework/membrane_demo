import "../css/app.scss"
//
import "phoenix_html"

import {Room} from "./room";
import { Socket } from "phoenix"

let room;
const socket = new Socket("/socket");
socket.connect();

const roomEl = document.getElementById("room");
if (roomEl) {
  room = new Room(socket, roomEl.dataset.roomId);
} else {
  console.error("room element is missing, cannot join video room");
}
