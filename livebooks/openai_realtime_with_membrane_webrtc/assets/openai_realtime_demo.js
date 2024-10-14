const pcConfig = { iceServers: [{ urls: "stun:stun.l.google.com:19302" }] };
const mediaConstraints = { video: false, audio: true };

const proto = window.location.protocol === "https:" ? "wss:" : "ws:";
const wsBrowserToElixir = new WebSocket(`${proto}//${window.location.hostname}:8829`);
const connBrowserToElixirStatus = document.getElementById("status");
wsBrowserToElixir.onopen = (_) => start_connection_browser_to_elixir(wsBrowserToElixir);
wsBrowserToElixir.onclose = (event) => {
  connBrowserToElixirStatus.innerHTML = "Disconnected";
  console.log("WebSocket connection was terminated:", event);
};

const start_connection_browser_to_elixir = async (ws) => {
  const localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
  const pc = new RTCPeerConnection(pcConfig);

  pc.onicecandidate = (event) => {
    if (event.candidate === null) return;
    console.log("Sent ICE candidate:", event.candidate);
    ws.send(JSON.stringify({ type: "ice_candidate", data: event.candidate }));
  };

  pc.onconnectionstatechange = () => {
    if (pc.connectionState == "connected") {
      const button = document.createElement("button");
      button.innerHTML = "Disconnect";
      button.onclick = () => {
        ws.close();
        localStream.getTracks().forEach((track) => track.stop());
      };
      connBrowserToElixirStatus.innerHTML = "Connected ";
      connBrowserToElixirStatus.appendChild(button);
    }
  };

  for (const track of localStream.getTracks()) {
    pc.addTrack(track, localStream);
  }

  ws.onmessage = async (event) => {
    const { type, data } = JSON.parse(event.data);

    switch (type) {
      case "sdp_answer":
        console.log("Received SDP answer:", data);
        await pc.setRemoteDescription(data);
        break;
      case "ice_candidate":
        console.log("Recieved ICE candidate:", data);
        await pc.addIceCandidate(data);
        break;
    }
  };

  const offer = await pc.createOffer();
  await pc.setLocalDescription(offer);
  console.log("Sent SDP offer:", offer);
  ws.send(JSON.stringify({ type: "sdp_offer", data: offer }));
};

const audioPlayer = document.getElementById("audioPlayer");
const wsElixirToBrowser = new WebSocket(`${proto}//${window.location.hostname}:8831`);
wsElixirToBrowser.onopen = () => start_connection_elixir_to_browser(wsElixirToBrowser);
wsElixirToBrowser.onclose = (event) => console.log("WebSocket connection was terminated:", event);

const start_connection_elixir_to_browser = async (ws) => {
  audioPlayer.srcObject = new MediaStream();

  const pc = new RTCPeerConnection(pcConfig);
  pc.ontrack = (event) => audioPlayer.srcObject.addTrack(event.track);
  pc.onicecandidate = (event) => {
    if (event.candidate === null) return;

    console.log("Sent ICE candidate:", event.candidate);
    ws.send(JSON.stringify({ type: "ice_candidate", data: event.candidate }));
  };

  ws.onmessage = async (event) => {
    const { type, data } = JSON.parse(event.data);

    switch (type) {
      case "sdp_offer":
        console.log("Received SDP offer:", data);
        await pc.setRemoteDescription(data);
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        ws.send(JSON.stringify({ type: "sdp_answer", data: answer }));
        console.log("Sent SDP answer:", answer);
        break;
      case "ice_candidate":
        console.log("Recieved ICE candidate:", data);
        await pc.addIceCandidate(data);
    }
  };
};
