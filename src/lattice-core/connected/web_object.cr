require "digest/sha1"
require "./connected_event"
module Lattice
  module Connected

    abstract class WebObject
      # OPTIMIZE it would be better to have a #self.all_instances that goes through @@instances of subclasses
      SIGNATURE_SIZE = 8 # the number of SHA256 digits to include in the instance signature
      INSTANCES = Hash(String, self).new      # all instance, with key as signature
      @signature : String?
      @@instances = Hash(String, String).new  # individual instances of this class (CardGame, City, etc)
      @@observer = EventObserver.new
      class_getter instances

      @subscribers = [] of HTTP::WebSocket
      @observers = [] of self
      property index = 0 # used when this object is a member of Container(T) subclass
      property version = Int64.new(0)
      property creator : WebObject?
      property subscribers # Each instance has its own subcribers.
      getter observers   # we talk to objects who want to listen by sending a listen_to messsage
      property name : String


      # a new thing must have a name, and that name must be unique so we can
      # find them across instances.
      def initialize(@name : String, @creator : WebObject? = nil)
        self.class.add_instance self
        after_initialize
      end

      def after_initialize
      end

      def simple_class
        self.class.simple_class
      end

      def self.simple_class
        self.to_s.to_s.split("::").last
      end

      # get the index from the parent
      def self.child_of(creator : WebObject, name : String)
        obj = new(name: name )
        obj.creator = creator
        obj.index = creator.as(Container).next_index
        obj
      end

      def self.instance(dom_id : String)
        INSTANCES[dom_id]?
      end

      # keep track of all instances, both at the class level (each subclass) and the 
      # abstract class level.
      def self.add_instance( instance : WebObject)
        INSTANCES[instance.signature] = instance
        @@instances[instance.name] = instance.signature
      end

      # simple debugging catch early on if we are forgetting to clean up after ourselves.
      def self.display_all
        "There are a total of #{INSTANCES.size} WebObjects with a total of #{INSTANCES.values.flat_map(&.subscribers).size} subscribers"
      end

      def content
      end

      def get_data  # added for GlobalStats
      end

      # useful for logging, etc
      def to_s
        dom_id
      end

      # either the session & the value exist or its nil
      def session_string( session_id : String, value_of : String)
        if (session = Session.get(session_id)) && (value = session.string?(value_of) )
          return value
        end
      end

      # send a message to given sockets
      def send(msg : ConnectedMessage, sockets : Array(HTTP::WebSocket))
        emit_event DefaultEvent.new(
          event_type: "message",
          sender: self,
          dom_item: dom_id,
          action: msg,
          session_id: nil,
          socket: nil,
          direction: "Out"
        )


        sockets.each do |socket|
          Connected.log :out, "Sending #{msg} to socket #{socket.object_id}"
          socket.send msg.to_json
        end
      end

      def update_attribute( change, subscribers : Array(HTTP::WebSocket) = self.subscribers )
        msg = { "dom"=>change.merge({"action"=>"update_attribute"}) }
        send msg, subscribers
      end

      def update( change, subscribers : Array(HTTP::WebSocket) = self.subscribers )
        msg = { "dom"=>change.merge({"action"=>"update"}) }
        send msg, subscribers
      end

      def act( action , subscribers : Array(HTTP::WebSocket) = self.subscribers  )
        msg = {"act" => action}
        send msg, subscribers
      end

      def insert( change, subscribers : Array(HTTP::WebSocket) = self.subscribers  )
        msg = { "dom"=>change.merge({"action"=>"insert"}) }
        send msg, subscribers
      end

      # Converts a dom-style id and extracts that last number from it
      # for example, "card-3" returns 3.
      def index_from( source : String, max = 100 ) 
        id = source.split("-").last.try &.to_i32
        id if id && id <= max && id >= 0
      end

      # A subscriber, with the _session_id_ given, has oassed in an action
      # called from WebSocket#on_message
      def subscriber_action(dom_item : String, action : Hash(String,JSON::Type), session_id : String?, socket : HTTP::WebSocket)
        if session_id
          puts "#{self.class}(#{self.name}) just received #{action} for #{dom_item} from session #{session_id}"
        else
          puts "#{self.class}(#{self.name}) just received #{action} for #{dom_item} without session".colorize(:yellow)
        end
      end

      # if you're a really popular object, other objects want to hear what you have to say.  This
      # gives those object a change to register their interest.  Any observer gets a notification
      # when an event occurs on a listened-to object
      def add_observer( observer : WebObject)
        @observers << observer unless @observers.includes? observer
      end

      # the entry point for creating events.  The @observer
      # handles sending them to various endpoints
      def emit_event(event : ConnectedEvent)
        @@observer.on_event(event, self)
      end

      # Fires when an event occurs on any instance of this class.
      def self.on_event(event : ConnectedEvent, speaker : WebObject)
      end

      # an on_event fires here, in the observing instance
      def on_event(event : ConnectedEvent, speaker : WebObject)
        puts "#{dom_id.colorize(:green).on(:white).to_s} Observed Event: #{event.colorize(:blue).on(:white).to_s} from #{speaker}"
      end

      # observe fires in the observer.  The data is wrapped into a ConnectedMessage and on_event fired
      def observe(talker, dom_item : String, action : ConnectedMessage, session_id : String | Nil, socket : HTTP::WebSocket, direction : String)
        event = DefaultEvent.new( talker, dom_item, action, session_id, socket, direction)
        # @events << event
        on_event event, self
      end

      # subscribers are sockets.  This sets one endpoint at a WebObjec tinstance , while
      # the other end of the endpoint is the user's browser.  Since each browser does it, it's 
      # a one-to-many relationship (one server object to many browser sockets).
      def subscribe( socket : HTTP::WebSocket , session_id : String?)
        unless subscribers.includes? socket
          subscribers << socket
          subscribed session_id, socket if session_id
        else
          # if things are working correctly, we shouldn't ever see this.
          puts "socket #{socket.object_id} already in #{subscribers.map &.object_id}".colorize(:red)
        end
      end

      # this session and socket are now subscribed to this object
      def subscribed( session_id : String, socket : HTTP::WebSocket)
      end

      # tests if a socket is subscribed
      def subscribed?( socket : HTTP::WebSocket)
        subscribers.includes? socket
      end

      # delete a subscription for _socket_
      def unsubscribe( socket : HTTP::WebSocket)
        subscribers.delete(socket)
        unsubscribed socket
      end

      # this socket is now unsubscribed from this object
      def unsubscribed( socket : HTTP::WebSocket)
      end

      # Called during page rendering prep as a spinup for an object.  Instantiate a new 
      # object (if requested), return the javascript and object for rendering.
      def self.preload(name : String, session_id : String, create = true)
        if (existing = @@instances.fetch(name,nil))
          target = from_signature(existing)
        else
          target = new(name)
        end
        return { javascript(session_id,target), target.as(self) }
      end

      def self.js_var
        # "#{self.to_s.split("::").last.downcase}Socket"
        "connected_object"
      end

      # # The dom id .i.e <div id="abc"> for this object.  When later parsing this value
      # # the system will look for the largest valued number in the dom_id, so it is ok
      # # to use values like "clock24-11929238" which would return 11929238.
      # def dom_id
      #   "#{self.class.to_s.split("::").last.downcase}-#{object_id}"
      # end

      # a publicly-consumable id that can be used to find the object in ##from_dom_id
      def dom_id : String
        #@dom_id ||= "#{self.class.to_s.split("::").last}-#{signature}"
        "#{simple_class}-#{signature}"
      end

      # come up with a signature that is unique to an instantiated object.
      def signature
        @signature ||= Digest::SHA1.hexdigest("#{self.class} #{self.object_id} #{Random.rand}")[0..SIGNATURE_SIZE - 1]
      end

      # given a dom_id, attempt to figure out if it is already instantiated
      # as k/v in INSTANCES, or instantiate it if possible.
      def self.from_dom_id( dom : String)
        klass, signature = dom.split("-").first(2)
        # for objects that stay instantiated on the server (objects that are being used
        # by multiple people or that require frequent updates) the default is to use
        # the classname-signature as a dom_id.  The signature is something that is sufficiently
        # random that we can quickly determine if an object is "real".
        if (obj = from_signature(signature))
          return obj if obj.class.to_s.split("::").last == klass
        end
      end

      def self.find(name)
        if (signature = instances[name]?)
          INSTANCES[signature]
        end
      end

      def self.from_dom_id!(dom : String) : self
        from_dom_id(dom).as(self)
      end

      def self.from_signature( signature : String)
        if (match = /^[0-9,a-f]{#{SIGNATURE_SIZE}}$/.match signature)
          if ( instance = INSTANCES[signature]? )
            return instance
          end
        end
      end

      # this creates a connection back to the serverm immediately calls back with a session_id
      # and the element ids to which to subscribe.
      # It then creates event observers for actions on subscribed objects, currently
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
              console.log(msg)
            }

        };

        connectEvents(#{js_var});

        JS
      end

      def self.subclasses
        {{@type.all_subclasses}}
      end

    end


  end
end
