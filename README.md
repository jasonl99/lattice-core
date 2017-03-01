# lattice-core

A [crystal-lang](https://github.com/crystal-lang/crystal) framework built on [kemal](https://github.com/kemalcr/kemal) that takes a realtime-first approach to web development.

## Background

What happens when you type in an address in your browser's address bar and hit enter? A lot, actually.  A request gets built, a connection established, information is exchanged (for example, what monitor resolution do I have, what operating system am I using, what browser?)  The server takes this request, maps it against known addresses, authenticates you, creates a response by querying a database or large-scale caching system, and sends it, along with a bunch of headers that tell your browser how to react and what to do with the data.  It spits out an enormous amount of data to display the current _state_ of something.  Moments later that state is wrong and needs to be updated.  

And for what purpose?  Have you ever looked at the same page or two different computers?  It's almost identical, with some customization for each user.    Making matters worse, the web has always been a stateless system; once a web page is transferred, the server forgets you like a bad sandwich.

We don't want that!  When I look at a baseball scoreboard, I want to see the current score of each game, complete with ball & strike counts for the current at-bat.  When I look at a stock price, I want to see the trade that occurred _just now_.  When I look at a news story, I want to see an chart that shows how other people are reacting to the story.   

Applications that run on your phone or computer are interactive - they feel _immediate_.   When you press a button, the screen changes _now_.   

Modern web development has gone a long way to making  web sites more like local apps, but it's hard to do.  It's a nightmare to keep track of which objects update, and if they are going to interfere with each other.  It's also horribly inefficient -- every little update has a ton of overhead on both the server and browser.

### State

A lot of this difficult comes about because we take something we created (a scoreboard page that shows the Red Sox beating the Yankees 3-0), and try to keep it in sync with the server.  We  resort to sleight-of-hand and create requests that run every 10 or 20 seconds and get the latest score.    We try to keep each side's state the same.

Think about that for a second:  Let's say we have a thousand users looking at a scoreboard page, and our javascript code polls it every ten seconds for updates.  That's 6,000 requests  a minute for the simple act of seeing if any scores changed.  Requests that the server has to look up (load from storage, render html).  It's insanity, is what it is.  

At some point, our server learned that the Red Sox had taken a 4-0 lead.  In the current system, those thousand users, spread out over the next ten seconds, will see the new score (many of them happy about it).  But the barrage doesn't stop.  It keeps coming, our now-annoyed server wondering why it has to keep telling all these users "IT'S STILL 4-0 LEAVE ME ALONE!" 

This happens for one reason:  the http protocol was designed to just send a message and hang up.    In the early days of the web, this worked fine, there really was no means to create dynamic content, so it didn't matter.  Today, not so much.

I happened to see a demo that showed how Kemal does a realtime chat and thought, "wow, that's actually a lot easier than I thought it would be."  It was a little spark.    What if an entire framework was written in the same way?  What if the server didn't just hang up every time I requested something.    

## Design Goals

There are several design goals of lattice core.

### Server Persistence

Every connected object, be it a scoreboard, individual score, individual player (in short, an instance of `WebObject`) remains instantiated on the server while there are users interested in it.  Users are also remaining instantiated on the server.

How do we know if there are users interested?  They `subscribe` to an WebObject.  This means that updates are sent to their browser.  Not subscribed?  You don't get those events.  It also means that actions (as defined by the server) are sent back to a real object on the server.  If two people click on the same game, a single `game_object` receives each event and can do its thing.  

### Server Drives all Updates

The way ajax (or other polling methods) work today, the browser decides if it is displaying the right data.  It goes and asks the server if we need to update this score.  It's backwards.    But we now have a direct line to every browser, so the server itself can update the browser.  

### Everything is Object Oriented

Every `web_object` has a `#to_html` method, which creates the entire thing, element tags and all.  Creating an element is done entirely within `WebObject`, and all subscriptions handled automatically, and there are plenty of helper methods to tweak the output.    What makes this particularly appealing is you can simply create web_objects that contain other web_objects.

For example, to create a scoreboard, it's as simple as this:

```ruby
class LeagueScores < Lattice::Connected::WebObject
end

class Scoreboard < Lattice::Connected::WebObject
  property scores = [] of LeagueScores
  scores << LeagueScores("nhl")
  scores << LeagueScores("mlb")
  scores << LeagueScores("nba")
  scores << LeagueScores("nfl")
  
  def content
    scores.map(&.to_html).join
  end
end
```

With that, you can now call `scoreboard.to_html` and have a ready-to-go chunk of html that will update in realtime. 

## WebSockets

This framework currently uses WebSockets as a message transport between client and server.  There are exactly two places messages are exchanged (`WebSocket#on_message` and `WebSocket#send`, and they are simply strings.

This means it'll be trivial to use other realtime, two-way technologies (http/2, webRTC, whatever's next) as it becomes available for Crystal.  



# Is This Thing Ready To Use For Anything?

Yes, it's ready for experimentation, but that's about it.

I also want to make clear that I'm not someone with a traditional programming pedigree - I don't have any sort of computer science degree, and I really shudder at the thought of having to deal with the traditional language that comes with that territory (UML diagrams and design patterns make me want to get back burying my head in neovim).   But I've been doing this sort of thing for a pretty long time (I used an EPROM programmer to change my `Apple ][` into a `Jason ][`).  But I've only been playing around with Crystal for just a couple of months.  So please, if you see something that seems like a rookie mistake, be gentle.  

The API is not stable yet.  There's no databse integration, no user management.  Yet.

But the goal is to have a real, useful, fast framework to develop truly immersive websites that are a joy to use and fun to code.

# Show Me An Example

Ok, take a look at [card_game](https://github.com/jasonl99/card_game).  It is designedto illustrate the power of WebSockets in general, and this framework in particular.  You can clone it, update the shards, and run it in a few lines.

I'd also suggest you take a look at the [Lattice::Connected API](https://github.com/jasonl99/lattice-core/wiki/Lattice_Connected-API) wiki page.  It attempts to illustrate the concepts in a conversational manner, as if we're sitting around talking about it.  But it's also wildly changing still.

There's two new demo apps:  

[calculator](https://github.com/jasonl99/calculator) - A shareable calculator (everyone can punch buttons).

[md-live](https://github.com/jasonl99/md_live) - A demo that shows markdown rendered in real time as you type.  And this can also be shared (collaborate on a doc).  It's a demo, so don't expect to be able do much with it, but it illustrates the idea.  It uses crystal's markdown library for rendering.

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

