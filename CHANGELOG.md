# Version 0.15

More significant changes.  

### Lattice::User

This new class is now used to completely abstract sessions and sockets away from the app.    This class has a timeout method that is called when a session expires, and handles a socket connection.  The [a card game Player](https://github.com/jasonl99/card_game/blob/user_class/src/card_game/player.cr) is a good place to see how this works.

### Lattice::Connected

Various changes to WebSocket, WebObject and events to remove references to sockets and sessions, and instead include the new User as part of the message. 



### PLEASE NOTE

There is a bug in the LLVM compiler version less than 3.8(?) that causes Digest::SHA1.digest("some string") to return data inconsistently when building an app with `--release`.  This is used in lattice to create a signature for the dom_id.   This means that a --release build will not correctly connect dom_ids.



# Version 0.12

### Changes

A significant change for better handling the DOM; an object can now be completely contained and return via `to_html`.  Prior to this change, `WebObject` did not enclose itself with an html element.  It now does so, with options to control the generated tag (i.e., modify classes, add a DOM id).   For example, the card_game sample's `card_game.slang` previously did something like this to show the chat_room:

```slim
div.chat_room data-item=chat_room.dom_id data-subscribe=""
  == chat_room.content
```

In retrospect, this seems like a glaring oversight.  Now, `card_game.slang` only needs this:

```ruby
== chat_room.to_html
```

With this change, it becomes a lot easier to have a container, and now there's no need for `StaticBuffer`(strings) and `DynamicBuffer`(WebObjects).  The new [`ObjectList`](https://github.com/jasonl99/lattice-core/blob/cleaner_dom/src/lattice-core/connected/object_list.cr) handles both, and they can be intermixed.  In fact, this makes it easier to do add _any_ class that can have advanced rendering capabilities without the extra overhead of WebObject.  Consider a Counter class that just renders a...counter:

```ruby
class Counter
  property value = 0
  def to_html( dom_id )
    "<div><span data-item='#{dom_id}' class='counter'>#{@value}</span>"
  end
end
```

The index is already added to the passed dom_id from render_item. Subclassing ObjectList would be simple, and still allow other types:

```ruby
class CounterList < ObjectList
  alias ListType = Counter | WebObject | String
end
```

What makes this _especially_ crazy, is it's now possible to have nested containers, each rendering its own stuff.

#### Javascript

`app.js` had some changes required by this new methodology.  Events and subscriptions are now added automatically when content changes through any WebObject.

__However__, this is still a major work in progress.

# Version 0.11 

### Changes

* Added a `RingBuffer(T)` to keep a fixed number of items in an object.  For example, a chat_room might keep the last 100 ChatMessages.  It could do this with `messages = RingBuffer(ChatMessage).new(max_items: 100).`, Items are available in first-in, first-out in `#values`
* Changed behavior of `WebObject#dom_id` to create a more reliable id that can be extended more easily when searching for objects.   The key piece is provided by `#signature` .
* Added `WebObject#observer` and `WebObject#add_observer` to allow messaging between WebObjects.  Observers are added to an object by calling `#add_observer` with the observing object.  Any events that occur in the observered object are sent to the `observer#on_event` with a ConnectedMessage. 
* Added `Connected::EventObserver` which has a RingBuffer for events received.
