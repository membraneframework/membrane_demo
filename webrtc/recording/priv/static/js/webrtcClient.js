var webSocket;
var localStream;
var rtcConnections = {};
var rtcConfig;
var onRemoteVideo;

const offerOptions = {
    offerToReceiveAudio: 1,
    offerToReceiveVideo: 1
};

function startStreaming(webSocketUrl, localVideoFunction, remoteVideoFunction) {
    rtcConfig = config;
    onRemoteVideo = remoteVideoFunction;
    navigator.getUserMedia(
        {audio: true, video: true},
        (stream) => {localVideoFunction(stream); openConnection(webSocketUrl);}, 
        (e) => {alert(e)});
}

function openConnection(webSocketUrl) {
    socket = new WebSocket(webSocketUrl);
    socket.onmessage = socketMessage;
}
function onAnswer(data, from) {
    rtcConnections[from].setRemoteDescription(data);
}

function onError(data, from) {
    console.dir(data);
}

function onJoined(data, from) {
    let peer_id = data.peer_id;
    startRTCConnection(peer_id);
    rtcConnections[peer_id].createOffer(
        getHandleDescription(peer_id, "offer"),
        console.dir, 
        offerOptions
    );    
}

function onCandidateMessage(data, from) {
    try {
        var candidate = new RTCIceCandidate(data);
        rtcConnections[from].addIceCandidate(candidate);
    } catch (e) {
        console.dir(e);
    } 
}

function onLeft(data, from) {
    delete rtcConnections[data.peer_id];
    var videoElement = document.getElementById(data.peer_id);
    videoElement.parentNode.removeChild(videoElement);
}

function onOffer(data, from) {
    startRTCConnection(from);
    let connection = rtcConnections[from];
    connection.setRemoteDescription(data) 
    connection.createAnswer(
        getHandleDescription(from, "answer"),
        console.dir,
    );    
}

function onRecording(data, from) {
    document.querySelector("#recording_msg").innerHTML = "Recording..."
}

function onRecorded(data, from) {
    window.location.href = "https://" + window.location.host + "/output/" + data.file_name;
    document.querySelector("#recording_msg").innerHTML = "Finished, downloading the recording..."
}

const messageEventListeners = {
    answer: onAnswer,
    authenticated: (data, from) => {console.log("Authenticated")},
    candidate: onCandidateMessage,
    error: onError,
    joined: onJoined,
    left: onLeft,
    offer: onOffer,
    recording: onRecording,
    recorded: onRecorded
};

function socketMessage(event) {
    message = JSON.parse(event.data);
    messageEventListeners[message.event](message.data, message.from);
}

function startRTCConnection(peer_id) {
    let connection = new RTCPeerConnection(config.rtcConfig);
    connection.addStream(localStream);
    connection.onicecandidate = getOnIceCandidate(peer_id);
    connection.ontrack = getHandleTrack(peer_id);
    rtcConnections[peer_id] = connection;
}

function getHandleTrack(peer_id) {
    return (event) => {onRemoteVideo(peer_id, event.streams[0]);};
}

function getOnIceCandidate(peer_id) {
    return function (event) {
        if(event.candidate != null) {
            var message = {to: [peer_id], event: "candidate", data: event.candidate};
            socket.send(JSON.stringify(message));
        }
    }
}

function getHandleDescription(peer_id, event) {
    return function(description) {
        rtcConnections[peer_id].setLocalDescription(description);
        message = {to: [peer_id], event: event, data: description};
        socket.send(JSON.stringify(message));
    }
}

function record() {
    document.querySelector("#recording_btn").style.display = "none";
    document.querySelector("#recording_msg").style.display = "block";
    socket.send(JSON.stringify({to: "all", event: "record"}));
}