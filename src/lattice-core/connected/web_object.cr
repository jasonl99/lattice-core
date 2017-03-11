require "digest/sha1"
require "./connected_event"

module Lattice
  module Connected

    class TooManyInstances < Exception
    end

    #TODO events need to abstract away session and web_socket stuff into Lattice::User
    abstract class WebObject
      # OPTIMIZE it would be better to have a #self.all_instances that goes through @@instances of subclasses
      INSTANCES = Hash(UInt64, self).new      # all instance, with key as signature
      @signature : String?
      @@instances = Hash(String, UInt64).new  # ("game1"=>12519823982) int is Base62.int_digest of signature
      @@observers = [] of WebObject
      @@event_handler = EventHandler.new
      @@max_instances = 1000  # raise an exception if this is exceeded.
      class_getter observers, instances, observer, emitter, event_handler

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
      property? propagate_event_to : WebObject?
      alias EventProc = Proc(String?, IncomingEvent, Nil)
      property event_listeners = {} of String=>Array(EventProc)


      def initialize(@name : String, @creator : WebObject? = nil)
        if (creator = @creator)
          creator_string = "#{creator.class} '#{creator.name}'" 
          @propagate_event_to = creator
        end
        check_instance_memory!
        self.class.add_instance self
        after_initialize
      end

      def self.find(name)
        if (signature = @@instances[name]?)
          INSTANCES[signature]
        end
      end

      def self.find_or_create(name, creator : WebObject? = nil)
        find(name) || new(name, creator)
      end

      def self.from_dom_id!(dom : String) : self
        from_dom_id(dom).as(self)
      end


      def handle_event( incoming : IncomingEvent )
        if incoming.action == "subscribe" && (sock = incoming.user.socket) && (sess = incoming.user.session.id)
         # puts "Subscribing to #{self}".colorize(:red).on(:white)
          subscribe(sock, sess) # this needs to be worked on.  Not sure this is the right place for subs
        else
        end
        @@event_handler.handle_event(incoming, self)
      end

      # event listeners on are procs that fire when an event has a particular event.action.  The
      # basic goal is to mirror javascript's event model names as much as convenient, but to expand
      # or change that as required to create new functionaility.  Effectively, these events close 
      # the loop:  we have add_event_listener here, and addEventListener in javascript
      # 
      # Since this is trying to mirror javascript, the data is stored for each event as an array
      # of procs"
      # { "click"=>[Proc<#123>, Proc<#102>], "mouseenter"=>[Proc<#12151231>] }
      def add_event_listener( action : String, &block : String?, IncomingEvent ->)
        puts "add_event_listener for #{action}"
        @event_listeners[action] = [] of EventProc unless @event_listeners[action]?
        event_listeners[action] << block
      end

      def on_event( event : IncomingEvent)
        # puts "#{self.to_s} IncomingEvent action (#{event.component} #{event.action} #{event.params}".colorize(:green).on(:white)
      end

      def observe_event( event : IncomingEvent | OutgoingEvent, target)
        # puts "#{self.to_s}#observe_event : #{event}".colorize(:green).on(:white)
      end

      def self.observe_event( event : IncomingEvent | OutgoingEvent, target)
        # puts "#{self.to_s}.class#observe_event : #{event}".colorize(:green).on(:white)
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
        base62_digest = Base62.int_digest(instance.signature)
        INSTANCES[base62_digest] = instance
        @@instances[instance.name] = base62_digest 
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

      def to_html( dom_id : String? = nil)
        open_tag(dom_id) + 
        content +
        close_tag
      end

      def content
        "<em><h3>Content for #{self.class} #{name} goes in #content </em>"
      end

      # useful for 
      def add_element_class( class_name)
        el_class = @element_options["class"]?
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
          # puts opt, val
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
        "#{self.class} #{self.name} (#{dom_id})"
      end

      # either the session & the value exist or its nil
      def session_string( session_id : String, value_of : String)
        if (session = Session.get(session_id)) && (value = session.string?(value_of) )
          return value
        end
      end

      # send a message to given sockets
      #def send(msg : Message, sockets : Array(HTTP::WebSocket))
      def send(msg , sockets : Array(HTTP::WebSocket))

        OutgoingEvent.new(
          message: msg,
          sockets: sockets,
          source: self
        )
      end

      def refresh
        update({"id"=>dom_id, "value"=>content}, subscribers)
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

      def add_class( html_class : String )
        add_class({"value"=>html_class})
      end

      def remove_class( html_class : String )
        remove_class({"value"=>html_class})
      end

      #-----------------------------------------------------------------------------------------
      # these go out to the sockets and would have a javascript handler on the users' browser
      def remove_class( change : Hash(String,JSON::Type), subscribers : Array(HTTP::WebSocket) = self.subscribers )
       # try merging in other direction to eliminate needing the id
        msg = { "dom"=>{"id"=>dom_id,"action"=>"remove_class"}.merge(change) }
        send msg, subscribers
      end

      def add_class( change : Hash(String,String), subscribers : Array(HTTP::WebSocket) = self.subscribers )
        # msg = { "dom"=>change.merge({"action"=>"add_class"}) }
        msg = { "dom"=>{"id"=>dom_id,"action"=>"add_class"}.merge(change) }
        send msg, subscribers
      end

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
      def self.add_observer( observer : WebObject )
        @@observers << observer
      end

      def propagate(event, to = @propagate_event_to)
        if event && to
          to.on_event(event, self)
        end
      end

      # subscribers are sockets.  This sets one endpoint at a WebObjec tinstance , while
      # the other end of the endpoint is the user's browser.  Since each browser does it, it's 
      # a one-to-many relationship (one server object to many browser sockets).
      # TODO a User should be subscribing.
      def subscribe( socket : HTTP::WebSocket , session_id : String?)
        unless subscribers.includes? socket
          subscribers << socket
          # notify of a user subscribption first, but then of a socket/session
          # if user not found
          if session_id && (user = User.find?(session_id) )
            subscribed(user)
          else
            subscribed session_id, socket if session_id
          end
          # update({"id"=>dom_id, "value"=>content}, [socket]) if auto_add_content
        else
          # if things are working correctly, we shouldn't ever see this.
        end
      end

      # this session and socket are now subscribed to this object
      def subscribed( session_id : String, socket : HTTP::WebSocket)
      end

      def subscribed( user : Lattice::User )
      end

      # tests if a socket is subscribed
      def subscribed?( socket : HTTP::WebSocket)
        subscribers.includes? socket
      end

      # delete a subscription for _socket_
      def unsubscribe( socket : HTTP::WebSocket)
        @subscribers.delete(socket)
        unsubscribed socket
      end

      # this socket is now unsubscribed from this object
      def unsubscribed( socket : HTTP::WebSocket)
      end

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
      # TODO it is not currently creating, not sure if that's possible with
      # signature?
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

      def self.from_signature( signature : String)
        base62_signature = Base62.int_digest(signature)
        if ( instance = INSTANCES[base62_signature]? )
          return instance
        end
      end

      def self.subclasses
        {{@type.all_subclasses}}
      end

    end


  end
end
