// Now part of app.js
// socket_protocol = "ws:"
// if (location.protocol === 'https:') { socket_protocol = "wss:" }
// connected_object = new WebSocket(socket_protocol + location.host + "/connected_object");
// connected_object.onmessage = function(evt) { handleSocketMessage(evt.data, evt) };
// connected_object.onclose = function(evt) { console.log("Connected Socket closed", evt) }
// document.addEventListener("DOMContentLoaded", function(evt) {
//   connected_object.onopen = function(evt) {
//     console.log("Socket connecting, configuring for updates..")
//     addSubscribers(document.querySelector("body"), self.target)
//     connectEvents()
//   };
// })

