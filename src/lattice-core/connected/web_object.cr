require "digest/sha1"
require "./connected_event"

module Lattice
  module Connected

    class TooManyInstances < Exception
    end

    abstract class WebObject
      # OPTIMIZE it would be better to have a #self.all_instances that goes through @@instances of subclasses
      INSTANCES = Hash(UInt64, self).new      # all instance, with key as signature
      @signature : String?
      @@instances = Hash(String, UInt64).new  # ("game1"=>12519823982) int is Base62.int_digest of signature
      # @@observer = EventObserver.new
      @@observers = [] of EventObserver | WebObject
      @@observers << EventObserver.new
      @@emitter = EventEmitter.new
      @@max_instances = 1000  # raise an exception if this is exceeded.
      class_getter observers
      class_getter instances
      class_getter observer
      class_getter emitter

      @subscribers = [] of HTTP::WebSocket
      @observers = [] of self
      @components = {} of String=>String
      @content : String?  # used as default content; useful for external content updates data.
      @element_options = {} of String=>String
      property index = 0 # used when this object is a member of Container(T) subclass
      property version = Int64.new(0)
      property creator : WebObject?
      property subscribers # Each {} of String=>String
      property observers   # we talk to objects who want to listen by sending a listen_to messsage
      property name : String
      property auto_add_content = true  # any data-item that is subscribed gets #content on subscribion

      def initialize(@name : String, @creator : WebObject? = nil)
        check_instance_memory!
        self.class.add_instance self
        after_initialize
      end

      def check_instance_memory!
        #TODO try garbage collecting first, and only then raise this erro.
        #gc would look for the first instance that has no subscribers,
        #call some on_=close method (so it could clean itself up, write to db, etc)
        #and then allow the instance to be created.
        if @@instances.size >= @@max_instances
          raise TooManyInstances.new("#{self.class} exceeds the maximum of #{@@max_instances}.")
        end
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

      def self.instance(signature : String)
        INSTANCES[Base62.int_digest signature]?
      end

      # keep track of all instances, both at the class level (each subclass) and the 
      # abstract class level.
      def self.add_instance( instance : WebObject)
        # puts "#{instance.class} #{instance.name} signature #{instance.signature}"
        # puts "Base62.int_digest instance.signature #{Base62.int_digest instance.signature}"
        INSTANCES[Base62.int_digest instance.signature] = instance
        @@instances[instance.name] = Base62.int_digest instance.signature
      end

      # Use Base62.string_digest
      # If this is a stored object (a databsae record, for example) the name
      # should represent that ("order-1021-jun2 155").  The idea is that a replicatable
      # piece of info, digested, is tough to duplicate unless you have the original pieces
      # that created it.
      def signature : String
        @signature ||= Base62.string_digest "#{self.class}#{self.name}"
      end

      # simple debugging catch early on if we are forgetting to clean up after ourselves.
      def self.display_all
        "There are a total of #{INSTANCES.size} WebObjects with a total of #{INSTANCES.values.flat_map(&.subscribers).size} subscribers"
      end

      def rendered_content( dom_id : String? = nil)
        open_tag(dom_id) + 
        content +
        close_tag
      end

      def content
        "<em><h3>Content for #{self.class} #{name} goes in #content </em>"
      end

      # useful for 
      def add_element_class( class_name)
        el_class = @element_options["class"]
        unless el_class && el_class.split(" ").includes? class_name
          @element_options["class"] = "#{el_class} #{class_name}".lstrip 
        end
      end

      # a header that contains this object and holds its dom_item
      def open_tag(rendered_dom_id : String? = nil)
        tag = @element_options.fetch("type", "div")
        # three options for dom id, selected in priority order
        data_item_id = rendered_dom_id || @element_options["data-item"]? || dom_id
        tag_string = "<#{tag} data-item='#{data_item_id}' "
        @element_options.reject {|opt,val| opt == "type"}.each do |(opt,val)|
          puts opt, val
          tag_string += "#{opt}='#{val}' "
        end
        tag_string += ">\n"
        tag_string
      end

      def close_tag
        "</#{@element_options.fetch("type","div")}>"
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
        bad_sockets = [] of HTTP::WebSocket
        sockets.each do |socket|
          Connected.log :out, "Sending #{msg} to socket #{socket.object_id}"
          begin
            socket.send msg.to_json
          rescue
            # if we can't send, we can't fix it, so just unsubscribe the user.
            # I've have this happen somewhat regularly when doing a poor-mans load test (i.e., hitting "ctrl-R" as fast as I can
            bad_sockets << socket
          end
        end
        bad_sockets.each {|sock| sock.close; subscribers.delete sock; WebSocket::REGISTERED_SESSIONS.delete sock}  # calling unsubscribe causes errors

        # puts "Message sent: #{msg}"
        emit_event DefaultEvent.new(
          event_type: "message",
          sender: self,
          dom_item: dom_id,
          message: msg,
          session_id: nil,
          socket: nil,
          direction: "Out")
      end

      def update_content( content : String, subscribers = self.subscribers)
        return if @content == content
        @content = content
        update({"id"=>dom_id, "value"=>content}, subscribers)
      end

      def update_component( component : String, value : _ , subscribers = self.subscribers)
        if !@components[component]? || @components[component] != value.to_s
          @components[component] = value.to_s
          update({"id"=>dom_id(component), "value"=>value.to_s}, subscribers)
        end
      end

      #-----------------------------------------------------------------------------------------
      # these go out to the sockets
      def update_attribute( change, subscribers : Array(HTTP::WebSocket) = self.subscribers )
        msg = { "dom"=>change.merge({"action"=>"update_attribute"}) }
        send msg, subscribers
      end

      def update( change, subscribers : Array(HTTP::WebSocket) = self.subscribers )
        msg = { "dom"=>change.merge({"action"=>"update"}) }
        send msg, subscribers
      end

      def append_value( change, subscribers : Array(HTTP::WebSocket) = self.subscribers )
        msg = { "dom"=>change.merge({"action"=>"append_value"}) }
        send msg, subscribers
      end

      def value( change, subscribers : Array(HTTP::WebSocket) = self.subscribers )
        msg = { "dom"=>change.merge({"action"=>"value"}) }
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
      #-----------------------------------------------------------------------------------------

      # Converts a dom-style id and extracts that last number from it
      # for example, "card-3" returns 3.
      def index_from( source : String, max = 100 ) 
        id = source.split("-").last.try &.to_i32
        id if id && id <= max && id >= 0
      end


      # if you're a really popular object, other objects want to hear what you have to say.  This
      # gives those object a change to register their interest.  Any observer gets a notification
      # when an event occurs on a listened-to object
      def add_observer( observer : WebObject)
        @observers << observer unless @observers.includes? observer
      end

      # a class observer is a little different, it just listens to events but has
      # no rendering capability of its own.  It would be a composite object that
      # would handle this (in other words, an observer would have a @something WebObject
      # to display what is observed
      def self.add_observer( observer : EventObserver | WebObject )
        @@observers << observer
      end

      # the entry point for creating events.  The @observer
      # handles sending them to various endpoints
      def emit_event(event : ConnectedEvent)
        @@emitter.emit_event(event, self)
      end

      # Fires when an event occurs on any instance of this class.
      def self.on_event(event : ConnectedEvent, speaker : WebObject)
        # puts "#{to_s} class event: #{event.event_type} #{event.direction} from #{speaker.name} for #{event.dom_item}".colorize(:blue).on(:light_gray)
      end

      # an on_event fires here, in the observing instance
      def on_event(event : ConnectedEvent, speaker : WebObject)
      #  puts "#{dom_id.colorize(:green).on(:white).to_s} Observed Event: #{event.colorize(:blue).on(:white).to_s} from #{speaker}"
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
          # update({"id"=>dom_id, "value"=>content}, [socket]) if auto_add_content
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
      #TODO create an event for unsubscribe?
      def unsubscribe( socket : HTTP::WebSocket)
        subscribers.delete(socket)
        unsubscribed socket

        #event is emitted after unsubbing, or it will try to send it to the socket that is in flux
        emit_event DefaultEvent.new(
          event_type: "unsubscribe",
          sender: self,
          dom_item: dom_id,
          message: nil,
          session_id: nil,  #TODO we can get the session id from the socket.
          socket: nil,      #It might be useful to pass this on so further cleanup can be done.
          direction: "In"
        )
      end

      # this socket is now unsubscribed from this object
      def unsubscribed( socket : HTTP::WebSocket)
      end

      # Called during page rendering prep as a spinup for an object.  Instantiate a new 
      # object (if requested), return the javascript and object for rendering.
      def self.preload(name : String, session_id : String, create = true)
        if (existing = @@instances.fetch(name,nil))
          target = INSTANCES[existing]
        else
          target = new(name)
        end
        return { javascript(session_id,target), target.as(self) }
      end

      def self.js_var
        # "#{self.to_s.split("::").last.downcase}Socket"
        "connected_object"
      end

      # a publicly-consumable id that can be used to find the object in ##from_dom_id
      def dom_id( component : String? = nil ) : String
        if component
          @components[component] = "" unless @components[component]?
          component = "-#{component}"
        end
        "#{simple_class}-#{signature}#{component}"
      end

      # given a full dom_id that contains this object, this strips
      # the dom_id and returns just the component portion, which is
      # the key for @components
      # this assumes there is a "-" between the dom_id and the component
      def component_id( val : String)
        if val.starts_with?(dom_id) && val.size > dom_id.size + 1
          val[dom_id.size+1..-1]
        end
      end

      # a component_id can have a -number as an internal index
      # within WebObject.
      def component_index (val : String?)
        return unless val # obviously there's no idx
        val.split("-").last.to_i32?
      end



      # given a dom_id, attempt to figure out if it is already instantiated
      # as k/v in INSTANCES, or instantiate it if possible.
      def self.from_dom_id( dom : String)
        if (split = dom.split("-") ).size >= 2
          klass, signature = dom.split("-").first(2)
          # for objects that stay instantiated on the server (objects that are being used
          # by multiple people or that require frequent updates) the default is to use
          # the classname-signature as a dom_id.  The signature is something that is sufficiently
          # random that we can quickly determine if an object is "real".
          if (obj = from_signature(signature))
            return obj if obj.class.to_s.split("::").last == klass
          end
        end
      end

      def self.find(name)
        if (signature = @@instances[name]?)
          INSTANCES[signature]
        end
      end

      def self.find_or_create(name)
        find(name) || new(name)
      end

      def self.from_dom_id!(dom : String) : self
        from_dom_id(dom).as(self)
      end

      def self.from_signature( signature : String)
        # puts "from_signature looking for '#{signature}' int_digest #{Base62.int_digest signature}"
        # puts signature.inspect
        # puts Base62.int_digest signature
        # puts "Instance sigs: #{INSTANCES.values.map &.signature}"
        if ( instance = INSTANCES[Base62.int_digest signature]? )
          return instance
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
        session_id = "#{session_id}"
        #{js_var} = new WebSocket("ws:" + location.host + "/connected_object");
        #{js_var}.onmessage = function(evt) { handleSocketMessage(evt.data) };
        #{js_var}.onopen = function(evt) {
            // on connection of this socket, send subscriber requests
            subs = document.querySelectorAll("[data-item]")
            for (var i=0;i<subs.length;i++){
              msg = {}
              id = subs[i].getAttribute("data-item")
              console.log("Checking " + id)
              if ( id.split("-").length == 2 ) {
                msg[ id ] = {action:"subscribe",params: {session_id:"#{session_id}"}}
                console.log("subscribing",msg)
                evt.target.send(JSON.stringify(msg))
               }
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
