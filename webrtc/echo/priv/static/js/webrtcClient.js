var webSocket;
var localStream;
var rtcConnection;
var rtcConfig;
var onRemoteVideo;

function startStreaming(webSocketUrl, localVideoFunction, remoteVideoFunction) {
    rtcConfig = config;
    onRemoteVideo = remoteVideoFunction;
    navigator.getUserMedia(
        {audio: true, video: {width: 1280, height: 720}},
        (stream) => {localVideoFunction(stream); openConnection(webSocketUrl);}, 
        (e) => {alert(e)});
}

function openConnection(webSocketUrl) {
    socket = new WebSocket(webSocketUrl);
    socket.onmessage = socketMessage;
}

function onError(data) {
    console.dir(data);
}

function onCandidateMessage(data) {
    try {
        var candidate = new RTCIceCandidate(data);
        rtcConnection.addIceCandidate(candidate);
    } catch (e) {
        console.dir(e);
    } 
}

function onOffer(data) {
    startRTCConnection();
    rtcConnection.setRemoteDescription(data)
    rtcConnection.createAnswer(
        getHandleDescription("answer"),
        console.dir,
    );    
}

const messageEventListeners = {
    candidate: onCandidateMessage,
    error: onError,
    offer: onOffer
};

function socketMessage(event) {
    message = JSON.parse(event.data);
    messageEventListeners[message.event](message.data);
}

function startRTCConnection() {
    rtcConnection = new RTCPeerConnection(config.rtcConfig);
    rtcConnection.addStream(localStream);
    rtcConnection.onicecandidate = getOnIceCandidate();
    rtcConnection.ontrack = getHandleTrack();
}

function getHandleTrack() {
    return (event) => {
        console.log(event)
        onRemoteVideo(event.streams[0].id, event.streams[0]);
    };
}

function getOnIceCandidate() {
    return function (event) {
        if(event.candidate != null) {
            var message = {event: "candidate", data: event.candidate};
            socket.send(JSON.stringify(message));
        }
    }
}

function getHandleDescription(event) {
    return function(description) {
        rtcConnection.setLocalDescription(description);
        message = {event: event, data: description};
        socket.send(JSON.stringify(message));
    }
}

function start_echo() {
    socket.send(JSON.stringify({event: "start"}));
}

function stop_echo() {
    socket.send(JSON.stringify({event: "stop"}));
}
