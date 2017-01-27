document.addEventListener("DOMContentLoaded", function(evt) {
    // Do stuff...
  document.getElementById("hand").addEventListener("click", function(evt) {
    id = evt.target.id;
    // FIXME Need to figure out a way to encapsulate js var name (cardgameSocket)
    cardgameSocket.send(JSON.stringify({"act":{"click":id}}))
  })
});



function handleSocketMessage(message) {
  payload = JSON.parse(message);
  console.log("Message receved:", payload)
  if ("dom" in payload) {
    modifyDOM(payload.dom);
  }
}

function modifyDOM(domData) {
  console.log(domData)
  if (el = document.getElementById(domData.id)) {
    switch (domData.action) {
      case "update":
        el.innerHTML = domData.value
        break;
      case "delete":
        el.parentNode.removeChild(el)
        break;
      case "insert":
        el.insertAdjacentHTML('beforeend',domData.value)
        break;
    }
  } else {
      console.log("cound not locate element " + domData.id)
  }
}
