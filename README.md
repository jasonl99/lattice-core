# lattice-core

A crystal-lang framework build on kemal that takes a WebSocket-first approach to web development.

## Background

Developing a website with data that updates in realtime -- instantly updating the page with changes 
as the occur on the server -- has always a challenging task:  you are creating event models for 
two objects:  one on the server (an object), and in the browser (a DOM node), and trying to 
maintain state between them.

That's challenging enough on its own.  Adding to the complexity is the fact that http is
inherently stateless, and now every update needs a whole setup and teardown process as
the browser creates a new request, the server creates up a new response 
with authentication happening along the way. Add the subsequent teardown, and you're looking 
at a _ton_ of work to update an element on a page.

The axiomatic way to do this has been use some javascript libarary that ulimately performs these
updates over AJAX.  The updates still happen in a stateless manner -- it's just that a lot of the 
complexity and overhead is invisibly buried and discarded by the javascript that performs the ajax.
But make no mistake browser and the server still work _a lot_ to update a little element on your
page.

Enter [WebSockets](https://www.websocket.org/quantum.html).  They are new, part of the HTML5 
spec.  They will only work on modern browsers.  And to be clear, there is no intention of 
making this framework work without them.  Think of it as a platform-specific framework:  
Instead of Android or iOS,  it's the "socket-ready browser" platform.  And it just so happens
that most Android and iOS browsers, as well as Chrome and FireFox on Windows, Mac, and Linux,
all support WebSockets.

## _Require_ websockets?  Why be so limiting?

I've been programming for a long time.  I've tried to learn different frameworks, and I've
played around many times with the "new language of the month."  It's incredibly overwhelming
to be faced with a new language that can do something a litle better, or that promises some
big advantage of last month's language darling.  The bottom line is there are a ton of 
frameworks out there already that do far more than I could ever hope to accomplish.

But something happened for me as I started experimenting with Crystal.  I can't (and won't) 
make any promises that you'll feel the same way.  Crystal's standard http library includes a 
nice implementation of WebSockets that's augmented by kemalcr.  Up until a few months ago, 
I thought WebSockets was something you used if you wanted to include video chats on your 
web page.  Never once had I written javascript to open a websocket.  But kemal has a quick 
and dirty chat app that intrigued me with its simplicity.  So I dug.  I'll freely admit 
I became a little obsessed.

As I dug deeper, I found WebSockets to be incredibly powerful for developing web apps that have
eliminate nearly all of the overhead and complexity that comes with ajax-first development.  It
has an awe-inspiring "the world is my oyster" power that I've experienced only a few times as a 
programmer (off the top of my head: Visual FoxPro for Windows, and Ruby come to mind).

In fact, your entire mindset changes - you stop thinking in terms of routing to 
pages that render a view, and start thinking in terms of events.  Elements on your page
are wired directly to the object on the server and vice-versa.  A button click instantly 
changes server state, and those changes instantly go to everyone looking at that object.

## Is This Thing Ready To Use For Anything?

Yes, it's ready for experimentation, but that's about it.

The API is not fleshed out yet.  There's no databse integration, no user management.

But the goal is to have a real, useful, fast framework to develop truly immersive websites 
that are a joy to use and fun to code. 

# Show Me An Example

Ok, take a look at [card_game](https://github.com/jasonl99/card_game).  It is designed
to illustrate the power of WebSockets in general, and this framework in particular.  You
can clone it, update the shards, and run it in a few lines.


## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  lattice-core:
    github: jasonl99/lattice-core
```

## Usage

```crystal
require "lattice-core"
```

TODO: Write usage instructions here

## Development

TODO: Write development instructions here

## Contributing

1. Fork it ( https://github.com/[your-github-name]/lattice-core/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [[your-github-name]](https://github.com/[your-github-name]) Jason Landry - creator, maintainer
