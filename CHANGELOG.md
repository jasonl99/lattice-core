# Version 0.11 

### Changes

* Added a `RingBuffer(T)` to keep a fixed number of items in an object.  For example, a chat_room might keep the last 100 ChatMessages.  It could do this with `messages = RingBuffer(ChatMessage).new(max_items: 100).`, Items are available in first-in, first-out in `#values`
* Changed behavior of `WebObject#dom_id` to create a more reliable id that can be extended more easily when searching for objects.   The key piece is provided by `#signature` .
* Added `WebObject#observer` and `WebObject#add_observer` to allow messaging between WebObjects.  Observers are added to an object by calling `#add_observer` with the observing object.  Any events that occur in the observered object are sent to the `observer#on_event` with a ConnectedMessage. 
* Added `Connected::EventObserver` which has a RingBuffer for events received.