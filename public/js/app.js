// This takes events specificed in the data-track attribute 
// and maps to native javascript addEventListener events, 
// modifying the behavior as needed.
function handleEvent(event_type, el, socket) {
  switch (event_type) {
    case "click":
      el.addEventListener("click", function(evt) {
        id = evt.target.getAttribute("data-item")
        msg = {mouse: {} }
        msg.mouse[id] = {action: "click"}
        socket.send(JSON.stringify(msg))
      })
    case "input":
      el.addEventListener("input", function(evt) {
        id = evt.target.getAttribute("data-item")
        msg = {input:{}}
        msg.input[id] = {action: "input", value: el.value}
        socket.send(JSON.stringify(msg))
      })
    case "mouseleave":
      el.addEventListener("mouseleave", function(evt) {
        id = evt.target.getAttribute("data-item")
        msg = {mouse: {}}
        msg.mouse[id] = {action: "mouseleave"}
        socket.send(JSON.stringify(msg))
      })
    case "mouseenter":
      el.addEventListener("mouseenter", function(evt) {
        id = evt.target.getAttribute("data-item")
        msg = {mouse:{}}
        msg.mouse[id] =  {action: "mouseenter"}
        socket.send(JSON.stringify(msg))
      })
    case "submit":
      el.addEventListener("submit", function(evt) {
        id = evt.target.getAttribute("data-item")
        evt.preventDefault();
        evt.stopPropagation();
        msg = {submit:{}}
        msg.submit[id] = formToJSON(el);
        msg.submit[id]["action"] = "submit"
        socket.send(JSON.stringify(msg))
        el.reset();  //TODO This is just a quick method of clearing the form for now
      })
      break;
  }
}

// given a form, this returns the data contained therein as
// a JSON object, with keys the element names, and the values
// the actual form values.
function formToJSON(form) {
  return [].reduce.call(form.elements, (data, element) => {
    data[element.name] = element.value;
    return data;
  }, {});
}

// given a string, return a trimmed array of items separated by commas
function getItems(item_list) {
  return item_list.split(",").filter(function(e){return e.trim()})
}

// given an element, set up javascript handlers for
// each event type found.  data-track is a comma-delimited
// list of events that map loosely to native javascript
// events recognized by addEventHandler, but we can also 
// define our own.
// i.e. <input type="text" data-track="click,keypress">
function handleElementEvents(el,socket) {
  event_types = getItems(el.getAttribute("data-track"));
  for (var i=0; i<event_types.length;i++) {
    handleEvent(event_types[i],el, socket)
  }
}

// sets up event tracking for a trackable object.  The websocket
// already will send data as needed _to_ this object from the server
// This finds nodes within the object that send data back to the
// server (clicks, form submits, etc)
function connectElement(el, socket) {
  evented_elements = el.querySelectorAll("[data-track]")
  for (var i=0; i<evented_elements.length; i++) {
    handleElementEvents(evented_elements[i], socket);
  }
}

// Wait until the DOM is loaded, then find all objects
// with a data-version attribute (our current way of
// indicating that this object communicates over a websocket).
// For each such element we find, call connectElement.
// which establishes _outgoing_ socket communication for events
// that happen to this element and its child nodes.
function connectEvents(socket) {
  document.addEventListener("DOMContentLoaded", function(evt) {
    connected = document.querySelectorAll("[data-version]")
    for (var i=0; i<connected.length; i++) {
      connectElement(connected[i], socket);
    }
  })
}  


// handle an incoming message over the socket
function handleSocketMessage(message) {
  payload = JSON.parse(message);
  if ("dom" in payload) {
    modifyDOM(payload.dom);
  }
}



// modify the dom based on the imformation contained in domData
function modifyDOM(domData) {
  // if (matches = document.querySelectorAll("#" + domData.id)) {
  if (matches = document.querySelectorAll("[data-item='" + domData.id + "']" )) {
    for (var i=0; i<matches.length; i++) {
      el = matches[i];
      switch (domData.action) {
        case "update":
          el.innerHTML = domData.value
          break;
        case "update_attribute":
          el.setAttribute(domData.attribute, domData.value)
          break;
        // case "attribute":
        //   el.innerHTML = domData.value
        //   break;
        case "delete":
          el.parentNode.removeChild(el)
          break;
        case "insert":
          el.insertAdjacentHTML('beforeend',domData.value)
          el.scrollTop = el.scrollHeight;
          if (maxChildren = el.getAttribute("data-maxChildren")) {
            children = el.children
            while (children.length > 0 && children.length > maxChildren) {
              el.removeChild(children[0])
            }
          }
          break;
      }
      el.closest("[data-version]").setAttribute("data-version",domData.version)
    }
  } else {
      console.log("cound not locate element " + domData.id)
  }
}
