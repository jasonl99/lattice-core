# lattice-core

A [crystal-lang](https://github.com/crystal-lang/crystal) framework build on [kemal](https://github.com/kemalcr/kemal) that takes a WebSocket-first approach to web development.

## Background

Developing a website with data that updates in realtime -- instantly updating the page with changes 
as the occur on the server -- has always a challenging task:  you are creating event models for 
two objects:  one on the server (an instantiated object of some kind), and in the browser (a DOM node), and trying to 
maintain state between them.

That's challenging enough on its own.  The server is an abstract representation, while the browser is a particular
visual representation of a subset of the server.  Adding to the complexity is the fact that http is
inherently stateless, and now every update needs a whole setup and teardown process as
the browser creates a new request, the server creates a new response. Add the subsequent teardown, and you're looking 
at a _ton_ of work to update an element on a page.

The axiomatic way to do this has been use some javascript libarary that ulimately performs these
updates over AJAX.  The updates still happen in a stateless manner -- it's just that a lot of the 
complexity and overhead is invisibly buried and discarded by the javascript that performs the ajax.
But make no mistake browser and the server still work _a lot_ to update a little element on your
page.  The analogy that occurs to me is an order from Amazon arriving in a big box,
with plastic bubble wrap and wads of paper keeping the item from sliding around.  It might be
a book, but the effort to get that book from Amazon (the server) to you (the browser) is an awful lot of work.
There's a lot of waste along the way.  

Enter [WebSockets](https://www.websocket.org/quantum.html).  They are relatively new, part of the HTML5 
spec.  They won't work on all browsers, but according to [this page](http://caniuse.com/#feat=websockets)
they are usable by more than 90% of current users.  That's not bad.  Just be clear, there is no intention of 
making this framework work without WebSockets, which means it also requires javascript.   Some people turn off
javascript.  This framework won't work for them either.  Think of it as a platform-specific framework:  
Instead of Android or iOS,  it's the "socket-ready browser" platform.  I think a platform that supports
90%_+ of users is a pretty good target.

## Yeah, but, _Require_ websockets?  Why be so limiting?

I've been programming for a long time.  I've experimented with different frameworks, and I've
played around many times with the newest "language of the month."  It's incredibly overwhelming
to be faced with a new language that can do something a litle better, or that promises some
big advantage of last month's favorite.  The bottom line is there are a ton of 
frameworks out there already that do far more than I could ever hope to accomplish in a more traditional
way.  The irony is also not lost on me -- Crystal itself is a pretty new language, and you could probably
make a convincing argument that I'm just using another language of the month.

But something happened for me as I started experimenting with Crystal.  I can't (and won't) 
make any promises that you'll feel the same way.  Crystal's standard http library includes a 
nice implementation of WebSockets that's augmented by kemal.  Up until a few months ago, 
I thought WebSockets were something you used if you wanted to include video steamoing on your 
web page.  Never once had I written javascript to open a websocket.  But kemal has an intriguing [chat demo](https://github.com/sdogruyol/kemal-chat) that struck me with its simplicity.  So I dug.  I'll freely admit 
I became a little obsessed.

Crystal has a beautiful syntax.  It's very much like Ruby, but it's compiled, so it's fast.  It's strongly-typed, but it does so without getting in your way.  I can't help think that Crystal has done for typing what ruby did for syntax.

As I dug deeper, I found WebSockets to be incredibly powerful and have the potential for developing web 
apps that have eliminate nearly all of the overhead and complexity that comes with ajax-first development.  It
has an awe-inspiring "the world is my oyster" power that I've experienced only a few times as a 
programmer (off the top of my head, it occurred with Visual FoxPro for Windows and Ruby.  And of course now Crystal).

In fact, your entire mindset changes - you stop thinking in terms of routing to 
pages that render a view, and start thinking in terms of events.  Elements on a page
are wired directly from each end user to the object on the server and vice-versa.  A button click can instantly 
change server state, and those changes can instantly go to everyone viewing at that object.

## Is This Thing Ready To Use For Anything?

Yes, it's ready for experimentation, but that's about it.

I also want to make clear that I'm not someone with a traditional programming pedigree - I don't have any sort of computer science degree, and I really shudder at the thought of having to deal with the traditional language that comes with that territory (UML diagrams and design patterns make me want to get back coding).   But I've been doing this sort of thing for a pretty long time (I used an EPROM programmer to change my `Apple ][` into a `Jason ][`).  I've been playing around with Crystal for just a couple of months.  So please, if you see something that seems like a rookie mistake, be gentle.  

The API is not stable yet.  There's no databse integration, no user management.

But the goal is to have a real, useful, fast framework to develop truly immersive websites 
that are a joy to use and fun to code.

# Show Me An Example

Ok, take a look at [card_game](https://github.com/jasonl99/card_game).  It is designed
to illustrate the power of WebSockets in general, and this framework in particular.  You
can clone it, update the shards, and run it in a few lines.

I'd also suggest you take a look at the [Lattice::Connected API](https://github.com/jasonl99/lattice-core/wiki/Lattice_Connected-API) wiki page.  It attempts to illustrate the concepts in a conversational manner, as if we're sitting around talking about it.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  lattice-core:
    github: jasonl99/lattice-core
```

## Usage

For now, I suggest you look at card_game.  It will be maintained alongside lattice-core so as the API changes, so will card_game.

## Contributors

- [Jason Landry](https://github.com/[your-github-name]) Jason Landry - creator, maintainer
