function handleSocketMessage(message) {
  payload = JSON.parse(message);
  if ("dom" in payload) {
    modifyDOM(payload.dom);
  }
}


function modifyDOM(domData) {
  if (matches = document.querySelectorAll("#" + domData.id)) {
    for (var i=0; i<matches.length; i++) {
      el = matches[i];
      switch (domData.action) {
        case "update":
          el.innerHTML = domData.value
          break;
        case "update_attribute":
          el.setAttribute(domData.attribute, domData.value)
          break;
        case "attribute":
          el.innerHTML = domData.value
          break;
        case "delete":
          el.parentNode.removeChild(el)
          break;
        case "insert":
          el.insertAdjacentHTML('beforeend',domData.value)
          break;
      }}
    el.closest("[data-version]").setAttribute("data-version",domData.version)
  } else {
      console.log("cound not locate element " + domData.id)
  }
}
