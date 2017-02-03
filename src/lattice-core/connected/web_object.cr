module Lattice::Connected

  class WebObject
    # OPTIMIZE it would be better to have a #self.all_instances that goes through @@instances of subclasses
    INSTANCES = Hash(UInt64, self).new      # all instances of any WebObject, across all subclasses
    @@instances = Hash(String, UInt64).new  # individual instances of this class (CardGame, City, etc)
    property version = 0
    class_property instances

    property subscribers = [] of HTTP::WebSocket   # Each instance has its own subcribers.
    property name : String
    
    # simple debugging catch early on if we are forgetting to clean up after ourselves.
    def self.display_all
      "There are a total of #{INSTANCES.size} WebObjects with a total of #{INSTANCES.values.flat_map(&.subscribers).size} subscribers"
    end

    def content
    end


    # either the session & the value exist or its nil
    def session_string( session_id : String, value_of : String)
      if (session = Session.get(session_id)) && (value = session.string?(value_of) )
        return value
      end
    end

    def update_attribute( change : Hash(String,String | Int32), subscribers : Array(HTTP::WebSocket) = self.subscribers )
      self.version +=1
      msg = { "dom"=>change.merge({"action"=>"update_attribute", "version"=>version}) }
      subscribers.each &.send(msg.to_json)
    end

    def update( change : Hash(String,String | Int32), subscribers : Array(HTTP::WebSocket) = self.subscribers )
      self.version +=1
      msg = { "dom"=>change.merge({"action"=>"update", "version"=>version}) }
      subscribers.each &.send(msg.to_json)
    end

    def insert( change : Hash(String,String | Int32), subscribers : Array(HTTP::WebSocket) = self.subscribers )
      self.version +=1
      msg = { "dom"=>change.merge({"action"=>"insert", "version"=>version}) }
      subscribers.each &.send(msg.to_json)
    end

    # Converts a dom-style id and extracts that last number from it
    # for example, "card-3" returns 3.
    def index_from( source : String, max = 100 ) 
      id = source.split("-").last.try &.to_i32
      id if id && id <= max && id >= 0
    end

    # a new thing must have a name, and that name must be unique so we can
    # find them across instances.
    def initialize(@name : String)
      INSTANCES[self.object_id] = self
      @@instances[@name] = self.object_id
    end

    # A subscriber, with the _session_id_ given, has oassed in an action
    def subscriber_action(dom_item : String, action : Hash(String,JSON::Type), session_id : String?, socket : HTTP::WebSocket)
      if session_id
        puts "#{self.class}(#{self.name}) just received #{action} for #{dom_item} from session #{session_id}"
      else
        puts "#{self.class}(#{self.name}) just received #{action} for #{dom_item} without session".colorize(:yellow)
      end
    end


    # def subscriber_action(data, session_id = nil)
    #   puts "#{self.class}(#{self.name}) just received #{data} from session #{session_id}"
    # end

    # a socket has requested a subscription to this object.  This means it will send & receive
    # messages across the _socket_ passed.  It is the initial handshake to a user  
    # It is the initial handshake between client and server.
    # def subscribe( socket : HTTP::WebSocket )
    #   unless subscribers.includes? socket
    #     subscribers << socket
    #     session_id = Lattice::Connected::WebSocket::REGISTERED_SESSIONS[socket.object_id]?  
    #     subscribed session_id, socket if session_id
    #   end
    # end
    def subscribe( socket : HTTP::WebSocket , session_id : String?)
      unless subscribers.includes? socket
        subscribers << socket
        subscribed session_id, socket if session_id
      else
        puts "socket #{socket.object_id} already in #{subscribers.map &.object_id}".colorize(:red)
      end
    end

    # This is a key piece for handling idividualization of a connected object.
    # A socket must subscribe to connected object, and #subscribe
    # automatically looks up the session_id for the socket, and if there is an 
    # association calls the this method with both the session and socket.  This is
    # This would be a time to establish any data structures necessary for a pareticular
    # subsubcription -- for example one hand in a card game, or a user's pot in a poker
    # game.
    # since updates go across sockets, it would make sense to do something with the object_id
    # of the socket as a reference.
    #```ruby
    # property subscribers : [] of HTTP::WebSocket
    # property player_hands : {} of UInt64 => Array(String)
    #  
    # def subscribed (session_id, socket)
    #   player_hands[socket.object_id] = draw_cards...
    # end
    # 
    # def display_hands
    #   self.subscribers.each_with_index do |socket, idx|
    #     hand = player_hands[socket.object_id]
    #     socket.update({"id"=>"#{dom_id}-mycard-#{idx}", "value"=>hand[idx]})
    #   end
    # end
    #```
    def subscribed( session_id : String, socket : HTTP::WebSocket)
    end

    def subscribed?( socket : HTTP::WebSocket)
      subscribers.includes? socket
    end
    # delete a subscription for _socket_
    def unsubscribe( socket : HTTP::WebSocket)
      subscribers.delete(socket)
    end

    def unsubscribed( socket : HTTP::WebSocket)
      subscribers.delete(socket)
      unsubscribed socket
    end

    # Called during page rendering prep as a spinup for an object.  Instantiate a new 
    # object (if requested), return the javascript and object for rendering.
    def self.preload(name : String, session_id : String, create = true)
      existing = @@instances.fetch(name,nil)
      if existing
        target = INSTANCES[existing]
      else
        target = new(name)
      end
      return { javascript(session_id,target), target }
    end

    def self.js_var
      # "#{self.to_s.split("::").last.downcase}Socket"
      "connected_object"
    end
   
    # The dom id .i.e <div id="abc"> for this object.  When later parsing this value
    # the system will look for the largest valued number in the dom_id, so it is ok
    # to use values like "clock24-11929238" which would return 11929238.
    def dom_id
      "#{self.class.to_s.split("::").last.downcase}-#{object_id}"
    end

    # this creates a connection back to the serverm immediately calls back with a session_id
    # and the element ids to which to subscribe.
    # It then creates event listeners for actions on subscribed objects, currently
    # just click events (more will come)
    # FIXME we have a problem right now when the same object is on the page twice: it only
    # updates one of them since document.getElementById only returns the first match.
    # this can be solved by using a class instead of an id (so cardgame-12312-card-2 is the
    # class, not the id.
    def self.javascript(session_id : String, target : _)
      javascript = <<-JS
        #{js_var} = new WebSocket("ws:" + location.host + "/connected_object");
        #{js_var}.onmessage = function(evt) { handleSocketMessage(evt.data) };
        #{js_var}.onopen = function(evt) {
            // on connection of this socket, send subscriber requests
            subs = document.querySelectorAll("[data-subscribe]")
            for (var i=0;i<subs.length;i++){
              msg = {}
              // OPTIMIZE - would it be better to get the id from data-subscribe rather than data-item?
              msg[ subs[i].getAttribute("data-item") ] = {action:"subscribe",params: {session_id:"#{session_id}"}}
              evt.target.send(JSON.stringify(msg))
            }

        };

        connectEvents(#{js_var});

      JS
      #          function(el){return el.id})   }}
      # old js:
      # //          evt.target.send( JSON.stringify( 
      # //            {"subscribe":{sessionID: "#{session_id}",
      # //             ids:  [].map.call(document
      # //              .querySelectorAll("[data-version]"),
      # //               function(el){return el.getAttribute("data-item")})   }}
      # //             ));

    end

    def self.subclasses
      {{@type.all_subclasses}}
    end

  end



end
