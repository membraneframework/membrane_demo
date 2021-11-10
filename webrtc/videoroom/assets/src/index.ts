import { Room } from "./room";

let room = new Room();
console.log("KURWA");
room.init().then(() => room.join());
