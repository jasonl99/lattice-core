socket_protocol = "ws:"
if (location.protocol === 'https:') { socket_protocol = "wss:" }
connected_object = new WebSocket(socket_protocol + location.host + "/connected_object");
connected_object.onmessage = function(evt) { handleSocketMessage(evt.data, evt) };
connected_object.onclose = function(evt) { console.log("Connected Socket closed", evt) }

document.addEventListener("DOMContentLoaded", function(evt) {
  connected_object.onopen = function(evt) {
    console.log("Socket connecting, configuring for updates..")
    addSubscribers(document.querySelector("body"), self.target)
    connectEvents()
  };
})


function sendEvent(msg,socket) {
  socket.send(JSON.stringify(msg)) 
}

function baseEvent(evt,event_action, action_params = {}) {
  // id = evt.target.getAttribute("data-item")
  // console.log(evt)
  msg = {}
  send_attribs = evt.target.getAttribute("data-event-attributes")
  if (!send_attribs) { send_attribs = "" }
  attribs = getItems(send_attribs)
  final_params = {}
  for (var i=0;i<attribs.length;i++) {
    final_params[attribs[i]] = evt.target.getAttribute(attribs[i])
  }
  for (var attrname in action_params) { 
    // copy the passed params into the event-attributes object that we created
    // This means that action_params takes precedence of 
    // param_attribs.  So if we are sending the elements <div class="myclass">
    final_params[attrname] = action_params[attrname]; 
  }
  id = evt.target.getAttribute("data-item")
  msg[id] = {action: event_action, params: final_params}
  return msg

}
// outgoing events look like this:// {"some-data-item": {action: "click", params: {x:123, y:232}}}
// On the server, the key is parsed for a valid, instantiated connectedObject
// that is subscribed to, and the action_parameters sent.
function handleEvent(event_type, el, socket, options = {formReset: true}) {
  switch (event_type) {
    case "click":
      console.log("Handling click event", el)
      el.addEventListener("click", function(evt) {
        msg = baseEvent(evt,"click")
        sendEvent(msg,socket)
        console.log("Clicked!", msg)
        // socket.send(JSON.stringify(msg))
      })
      break;
    case "input":
      el.addEventListener("input", function(evt) {
        msg = baseEvent(evt,"input", {value: el.value})
        sendEvent(msg,socket)
        // socket.send(JSON.stringify(msg))
      })
      break;
    case "mouseleave":
      el.addEventListener("mouseleave", function(evt) {
        msg = baseEvent(evt,"mouseleave")
        sendEvent(msg,socket)
        // socket.send(JSON.stringify(msg))
      })
      break;
    case "mouseenter":
      el.addEventListener("mouseenter", function(evt) {
        msg = baseEvent(evt,"mouseenter")
        sendEvent(msg,socket)
        // socket.send(JSON.stringify(msg))
      })
    case "submit":
      el.addEventListener("submit", function(evt) {
        evt.preventDefault();
        evt.stopPropagation();
        msg = baseEvent(evt, "submit", formToJSON(el))
        // console.log("Submitting:", msg)
        sendEvent(msg,socket)
        // socket.send(JSON.stringify(msg))
        if (options.formReset) {
          el.reset();  //TODO This is just a quick method of clearing the form for now
        }
      })
      break;
  }
}

// given a form, this returns the data contained therein as
// a JSON object, with keys the element names, and the values
// the actual form values.
function formToJSON(form) {
  return [].reduce.call(form.elements, (data, element) => {
    if (element.name && data) {
      data[element.name] = element.value;
    }
    return data;
  }, {});
}

// given a string, return a trimmed array of items separated by commas
function getItems(item_list) {
  return item_list.split(",").filter(function(e){return e.trim()})
}

// given an element, set up javascript handlers for
// each event type found.  data-events is a comma-delimited
// list of events that map loosely to native javascript
// events recognized by addEventHandler, but we can also 
// define our own.
// i.e. <input type="text" data-events="click,keypress">
function handleElementEvents(el,socket) {
  event_types = getItems(el.getAttribute("data-events"));
  for (var i=0; i<event_types.length;i++) {
    console.log("Handling",event_types[i],el)
    handleEvent(event_types[i],el, socket)
  }
}

// sets up event tracking for a trackable object.  The websocket
// already will send data as needed _to_ this object from the server
// This finds nodes within the object that send data back to the
// server (clicks, form submits, etc)
function connectElements(el, socket) {
  evented_elements = el.querySelectorAll("[data-events]")
  for (var i=0; i<evented_elements.length; i++) {
    handleElementEvents(evented_elements[i], socket);
  }
}

// Wait until the DOM is loaded, then find all objects
// with a data-subscribe attribute (our current way of
// indicating that this object communicates over a websocket).
// For each such element we find, call connectElement.
// which establishes _outgoing_ socket communication for events
// that happen to this element and its child nodes.
function connectEvents(el = document.querySelector("body"), socket = connected_object) {

  // form - any form under a data-item gets a submit event,
  // and for now its inputs get input events.
  // forms = el.querySelectorAll("[data-item] form")
  // for (var i=0; i<forms.length; i++) {
  //   form = forms[i]
  //   nearest_item = form.closest("[data-item]").getAttribute("data-item")
  //   id = el.getAttribute("name") || "form"
  //   form.setAttribute("data-item", nearest_item + "-" + id)
  //   handleEvent("submit", form, connected_object, {formReset: false})
  // }

  // formElements = el.querySelectorAll("[data-item] form input[name]")
  // // console.log("form elements", formElements)
  // for (var i=0; i<formElements.length; i++) {
  //   el = formElements[i]
  //   nearest_item = el.closest("[data-item]").getAttribute("data-item")
  //   id = el.getAttribute("name")
  //   el.setAttribute("data-item", nearest_item + "-" + id)
  //   handleEvent("input", el, connected_object)
  // }

  // compoents are a bit of a work in progress
  components = el.querySelectorAll("[data-component]")
  for (var i=0; i<components.length; i++) {
    component = components[i]
    nearest_item = component.closest("[data-item]:not([data-component])").getAttribute("data-item")
    id = component.getAttribute("data-component")
    component.setAttribute("data-item",nearest_item + "-" + id)
  }

  // for each element that has a data-events entry, set up the handlers
  connected = el.querySelectorAll("[data-events]")
  for (var i=0; i<connected.length; i++) {
    handleElementEvents(connected[i], socket);
  }
} 

// handle an incoming message over the socket
function handleSocketMessage(message, evt) {
  payload = JSON.parse(message);
  if ("dom" in payload) {
    // console.log("ServerClient Dom: ", payload.dom)
    modifyDOM(payload.dom);
  }
  if ("act" in payload) {
    // console.log("ServerClient Act: ", payload.act)
    takeAction(payload.act);
  }
  if ("error" in payload) {
    console.log("Server Reports Error: ", payload.error)
    alert(payload.error)
  }
  if ("close" in payload) {
    console.log("Session closing", evt)
    evt.target.close()
  }
}

function takeAction(domData) {
  if (matches = document.querySelectorAll("[data-item='" + domData.id + "']" )) {
    for (var i=0; i<matches.length; i++) {
      el = matches[i];
      switch (domData.action) {
        case "chomp":
          el.value = el.value.slice(0,-1);
        case "resetForm":
          el.reset();
          break;
      }
    }
  } else {
      console.log("could not locate element " + domData.id)
  }
}

// // this happens in connectEvents too
// function addListeners(el, socket = connected_object) {
//   connected = el.querySelectorAll("[data-events]")
//   for (var i=0; i<connected.length; i++) {
//     handleElementEvents(connected[i], socket);
//   }
// }

function addSubscribers(el, socket = connected_object) {
  connected = el.querySelectorAll("[data-item]")
  for (var i=0; i<connected.length; i++) {
    id = connected[i].getAttribute("data-item")
    if (id.split("-").length == 2) {
      msg = {}
      msg[ id ] = {action:"subscribe", params: {}}
      socket.send(JSON.stringify(msg))
    }
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
          connectEvents(el)
          addSubscribers(el)
          break;
        case "update_attribute":
          el.setAttribute(domData.attribute, domData.value)
          break;
        case "add_class":
          el.classList.add(domData.value)
          break;
        case "remove_class":
          console.log("Removing class " + domData.value + " from " + domData.id)
          el.classList.remove(domData.value)
          break;
        case "value":
          el.value = domData.value
          connectEvents(el)
          addSubscribers(el)
          break;
        case "append_value":
          el.value += domData.value
          connectEvents(el)
          addSubscribers(el)
          break;
        case "delete":
          el.parentNode.removeChild(el)
          break;
        case "insert":
          el.insertAdjacentHTML('beforeend',domData.value)
          el.scrollTop = el.scrollHeight;
          if (maxChildren = el.getAttribute("data-max-children")) {
            children = el.children
            while (children.length > 0 && children.length > maxChildren) {
              el.removeChild(children[0])
            }
          }
          connectEvents(el.lastChild)
          addSubscribers(el.lastChild)
          break;
      }
      // el.closest("[data-version]").setAttribute("data-version",domData.version)
    }
  } else {
      console.log("cound not locate element " + domData.id)
  }
}
