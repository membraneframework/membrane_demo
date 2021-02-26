import {Socket} from "phoenix";
import config from "./config";

export class Room {
  constructor(socket, roomId = "lobby") {
    // bind all functions as current babel preset does not allow arrow functions as
    // class properties... 
    this.setup = this.setup.bind(this);
    this.onLocalStream = this.onLocalStream.bind(this);
    this.startRTCConnection = this.startRTCConnection.bind(this);
    this.setupSocketConnection = this.setupSocketConnection.bind(this);
    this.start = this.start.bind(this);
    this.stop = this.stop.bind(this);
    this.onOffer = this.onOffer.bind(this);
    this.onCandidate = this.onCandidate.bind(this);
    this.onIceCandidate = this.onIceCandidate.bind(this);
    this.onTrack = this.onTrack.bind(this);
    this.onDescription = this.onDescription.bind(this);
    
    
    this.channel = null;
    this.config = config;
    this.localStream = null;
    this.rtcConnection = null;
    this.socket = socket;
    this.streams = [];
    
    socket.onError(() => {
      displayConnectionError();
      this.stop();
    });
    
    socket.onClose(() => {
      displayConnectionError();
      this.stop();
    });
    
    this.setup(roomId);
  }
  
  async setup(roomId) { 
    try {
      const constraints = {
        audio: true, 
        video: {width: 1280, height: 720}
      };
      
      const localStream = await navigator
        .mediaDevices
        .getUserMedia(constraints);
      
      this.onLocalStream(localStream);
      this.setupSocketConnection(roomId);
    } catch (error) {
      console.error(error);
    }
  }
  
  onLocalStream(stream) {
    this.localStream = stream;
    addVideoElement("local", stream);
    document.getElementById("local").muted = true;
  }
  
  startRTCConnection() {
    this.rtcConnection = new RTCPeerConnection(this.config);
    this.rtcConnection.addStream(this.localStream);
    this.rtcConnection.onicecandidate = this.onIceCandidate();
    this.rtcConnection.ontrack = this.onTrack();
  }
      
  
  setupSocketConnection(roomId) {
    this.channel = this.socket.channel(`room:${roomId}`, {});


    this.channel.join()
      .receive("ok", (_) => this.start())
      .receive("error", resp => { console.error("Unable to join room channel", resp) })
      
    this.channel.on("offer", this.onOffer);
    this.channel.on("candidate", this.onCandidate);
  }
  
  start() {
    this.channel.push("start", {});
  }
  
  stop() {
    this.channel.push("stop", {});
  }
  
  
  onOffer(data) {
    if (this.rtcConnection == null) {
      this.startRTCConnection();
    } else {
        this.rtcConnection.restartIce();
    }
    this.rtcConnection.setRemoteDescription(data.data)
    this.rtcConnection.createAnswer(
        this.onDescription("answer"),
        console.dir,
    );    
      
  }
  
  onCandidate(data) {
    try {
        const candidate = new RTCIceCandidate(data.data);
        this.rtcConnection.addIceCandidate(candidate);
    } catch (error) {
        console.dir(error);
    } 
  }
      
  onIceCandidate() {
      const {channel} = this;
      return function (event) {
          if(event.candidate != null) {
              channel.push("candidate", {data: event.candidate})
          }
      }
  }
  
  onTrack() {
      return (event) => {
          const [stream,] = event.streams;
          stream.onremovetrack = (event) => removeVideoElement(event.target.id);
          this.streams.push(stream);
          addVideoElement(stream.id, stream);
      };
  }

  onDescription(event) {
    const {channel, rtcConnection} = this;
    
    return function(description) {
        rtcConnection.setLocalDescription(description);
        channel.push(event, {data: description});
    };
  }
}

function addVideoElement(id, stream) {
  let video = document.getElementById(id);

  if(!video) {
      const template = document.querySelector("template");
      // TODO: check if this is correct
      // video = document.importNode(template.content, true);
      // video.querySelector("video").id = id;
      // // child.querySelector("label").innerText = id;
    
      video = document.createElement('video');
      video.id = id;
      document.getElementById("videochat").appendChild(video);
  }
  video.srcObject = stream;
  video.autoplay = true;
  video.playsinline = true;
}

function removeVideoElement(id) {
  const video = document.getElementById(id);
  if(video) {
      video.remove();
  }
}

function displayConnectionError() {
  document.getElementById("control").innerText = "Cannot connect to server, refresh the page and try again"
}