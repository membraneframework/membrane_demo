import "../css/app.scss"
//
import "phoenix_html"

import {Room} from "./room";
import { Socket } from "phoenix"

const socket = new Socket("/socket");
socket.connect();

const room = new Room(socket, "lobby");


