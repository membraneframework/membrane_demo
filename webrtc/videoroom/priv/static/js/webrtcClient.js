var rtcConnection;
var rtcConfig;
var onRemoteStream;
var onRemoveStream;
var onWSError;
var streams = [];

function setupConnection(webSocketUrl, onLocalStream, _onRemoteStream, _onRemoveStream, _onWSError) {
    rtcConfig = config;
    onRemoteStream = _onRemoteStream;
    onRemoveStream = _onRemoveStream;
    onWSError = _onWSError;
    navigator.getUserMedia(
        {audio: true, video: {width: 1280, height: 720}},
        (stream) => {onLocalStream(stream); openConnection(webSocketUrl);}, 
        (e) => {alert(e)}
    );    
}

function openConnection(webSocketUrl) {
    socket = new WebSocket(webSocketUrl);
    socket.onmessage = socketMessage;
    socket.onopen = () => {
        setInterval(() => socket.send("keep_alive"), 30_000);
        start();
    };
    socket.onclose = event => {
        console.error(event);
        stop();
        onWSError();
    };
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
    if (rtcConnection == null) {
        startRTCConnection();
    }
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
        stream = event.streams[0];
        stream.onremovetrack = (event) => {onRemoveStream(event.target.id)};
        streams.push(stream);
        onRemoteStream(stream);
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

function start() {
    socket.send(JSON.stringify({event: "start"}));
}

function stop() {
    socket.send(JSON.stringify({event: "stop"}));
    rtcConnection.close();
    rtcConnection = null;
    streams.forEach(stream => onRemoveStream(stream.id));
    streams = [];
}
