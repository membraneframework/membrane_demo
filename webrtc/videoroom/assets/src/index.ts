import { Room } from "./room";

let room = new Room();
try {
  room.join();
} catch (error) {
  console.log("error243", error);
}
