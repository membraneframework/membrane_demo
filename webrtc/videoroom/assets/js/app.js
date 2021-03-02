import "../css/app.scss"
//
import "phoenix_html"

import {Room} from "./room";
import { Socket } from "phoenix"

var room;
var socket = new Socket("/socket");
socket.connect();


export function joinRoom(roomId) {
  room = new Room(socket, roomId);
}
