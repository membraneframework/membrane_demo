const room = document.location.href.split("/").slice(-1)[0]
const webSocketUrl = "wss://" + window.location.host + "/ws";

function setupVideo(id, stream) {
    if(!document.getElementById(id)) {
        var template = document.querySelector("template");
        var child = document.importNode(template.content, true);
        child.querySelector("video").id = id;
        // child.querySelector("label").innerText = id;
        document.getElementById("videochat").appendChild(child);
    }
    document.getElementById(id).srcObject = stream;
}

function setupLocalVideo(stream) {
    setupVideo("local", stream);
    localStream = stream;
    document.getElementById("local").muted = true;
}

function setupRemoteVideo(stream) {
    setupVideo(stream.id, stream);
}

function removeVideo(stream_id) {
    video = document.getElementById(stream_id);
    if(video) {
        video.remove();
    }
}

function toggleStream() {
    btn = document.getElementById("toggleStream")
    if(btn.innerText == "Stop") {
        btn.innerText = "Start"
        stop();
    } else {
        btn.innerText = "Stop"
        start();
    }
}

function handleError() {
    document.getElementById("control").innerText = "Cannot connect to server, refresh the page and try again"
}

setupConnection(webSocketUrl, setupLocalVideo, setupRemoteVideo, removeVideo, handleError);