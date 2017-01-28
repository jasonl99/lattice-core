module Lattice::Connected

  # A cohort of WebObject used to create a client-server connection between a server-hosted
  # object (WebObject) and a client DOM-representation of that object.  To make the
  # as seamless as possible, with updates and actions ocurring as an event model on *both* sides
  # of the connection.
  #
  # In order to identify a particular user (which we do via an http session), we must
  # tie a socket to a session, and sockets subscribe to WebObjects.  Each
  # connected_object keeps track of its subscribers (via an HTTP::WebSocket) which it can use for
  # communication.  
  # 
  # This class in particular maintains an array that links a HTTP::WebSocket object_id to a 
  # Session id in WebSocket::REGISTERED_SESSIONS.
  # It handles incoming communication on the socket, establishes socket-session relationships,
  # registerers subscriptions to objects received over the socket, and forwards messages to
  # individual objects when received from a subscriber. 
  #
  # This is all done at the class level - no WebSocket instances are created
  # 
  # An important note on incoming messages:  This class has a very specific, simple rule
  # for sending commands:  the command is the key, and the value is the payload.  The 
  # system accepts only one command per message; the first key and value are used as that command.
  abstract class WebSocket

    VALID_ACTIONS = %w(subscribe act)
    REGISTERED_SESSIONS = {} of UInt64=>String

    # Verify that an incoming subscriber request contains valid data
    # an incoming message is a JSON object with a single key, which represents the action to take.
    # We verify this action against the WebSocket::VALID_ACTIONS.
    # an exception is three cases:
    # * More than one key is in the json sent (more than one action)
    # * All keys (the actions) must be in VALID_ACTIONS
    # * JSON.parse is unable to parse the incoming message
    def self.validate_payload(message : String)
       begin
         return_val = JSON.parse(message)
         payload = return_val.as_h
         raise "Invalid actions #{payload.keys - VALID_ACTIONS}" unless (payload.keys - VALID_ACTIONS).empty?    
         raise "Too many actions" unless payload.keys.size == 1
       rescue
         raise "Error validating and parsing socket message : #{message}"
      end
      return_val
    end

    # Given a session_id, return true if the Session instance is valid
    def self.verify_session( session_check : String | Nil )
      Session.get(session_check) if session_check
    end

    # Extracts UIn64s that are object_ids of instantiated WebObjects from _Array(JSON::Type)_
    # e.g., [11234, 1235, 1236] as JSON::Any becomes [1235] as Array(UInt64)
    # but ids may come like ["city-3", "cardgame-198272-3player"] so we strip non-digits
    # and end up with an array like this ["3","198272"], where the largest numeric id is 
    # used and the others disccard (we ignore 3player, but use city-3 since it's the only 
    # one).  This array is turned into Unit64s with only instantiated objects being returned
    def self.extract_ids( source : Array(JSON::Type) | Nil ) : Array(UInt64) 
      return [] of UInt64 unless source
      # ids maybe look like "45-cardgame-12312" so we only care about "-digits"
      uids = source.map(&.to_s).compact.map do |array_element|
        # this siplits the above example into ["45",12312"]
        # this is then converted u64 and the largest value returned
        # can't use squeeze here
        dom_numbers = array_element.gsub(/[^0-9]+/,' ').squeeze(' ').strip.split(" ")
        dom_numbers.map(&.to_u64).sort.last
      end
      uids.select {|the_id| WebObject::INSTANCES.has_key?(the_id)}
    end

    # given a socket, return an array of all instantiated WebObjects to which
    # the socket is subscribed.  For example, if a person is watching scores for 10 games
    # on a page, it would return the the ten NFLGame instances.
    def self.subscribed_to( socket : HTTP::WebSocket)
      WebObject::INSTANCES.select {|k,obj| obj.subscribers.includes? socket}
    end

    # Sockets and Sessions are tied together by the associative hash REGISTERED_SESSIONS.
    # each socket's object_id is used as they key, and the session's id as the value.  This
    # makes it trivial to find a session by a socket.
    # in this case we simply set the value, overwriting any that may be present
    def self.register_session(session, socket)
      REGISTERED_SESSIONS[socket.object_id] = session.id
      puts "REGISTERED_SESSIONS.size #{REGISTERED_SESSIONS.size}".colorize(:green) #debug
    end

    # A socket is created at the page-level; there may be dozens of DOM objects that 
    # are subscribed to.   The socket, at its convenience, sends a _subscribe_ action
    # to the server, which contains a session_id and the dom ids for which it would like
    # to subscribe.  After the session has been verified and registered, we extract the ids
    # from subscribed_data and send the `subscribe` message with out socket to each 
    # object.
    def self.subscribe( subscribe_data : Hash(String, JSON::Type) | Nil, socket : HTTP::WebSocket )
      # verify that a session exists, otherwise we don't allow a subscription
      return unless subscribe_data && (session = verify_session(subscribe_data["sessionID"].to_s))
      register_session(session.as(Session), socket)
      supplied_ids = extract_ids(subscribe_data["ids"].as(Array(JSON::Type)))
      supplied_ids.each do |id| 
        WebObject::INSTANCES[id].subscribe(socket)
      end
      memory_used
    end

    # a debugging aid to show how much data we have laying around
    def self.memory_used
      puts "WebSocket".colorize.underline
      puts "Registered Sessions: #{WebSocket::REGISTERED_SESSIONS}"
      puts 
      puts "WebObject".colorize.underline
      WebObject::INSTANCES.values.each do |instance|
        puts "  #{instance.to_s.colorize.underline} #{instance.name.colorize.underline}"
        puts "     Subscribers: #{instance.subscribers.size}"
      end
    end

    # OPTIMIZE this should also be used by extract_ids
    def self.extract_id( from : String)
      numbers = from.gsub(/[^0-9]+/,' ').squeeze(' ').strip.split(" ")
      numbers.map(&.to_u64).sort.last
    end

    # When an incoming message arrives, it must be from a particular object that has
    # already been subscribed to.  This processes the incoming message, determines which
    # object should receive it, and sends it to that object.
    def self.act ( action_data : Hash(String, JSON::Type), socket : HTTP::WebSocket )
      # action data is in the form of dom=>params 
      # FIXME this is sending subscriber_actions to all subscribed actions,
      # not just the one that was acted upon.
      
      # find the object for which the action happens
      id = extract_id( action_data.first_key)
      puts "id from #{action_data.first_key} is #{id}".colorize(:yellow)
      acted_object = WebObject::INSTANCES[id]
      session_id = REGISTERED_SESSIONS[socket.object_id]?
      acted_object.subscriber_action(action_data, session_id)
      # subscribed_to(socket).each_value do |subscribed_object|
      #   session_id = REGISTERED_SESSIONS[socket.object_id]?
      #   subscribed_object.subscriber_action(action_data, session_id)
      # end
    end

    # Handle an incoming socket message
    def self.on_message(message, socket)

      # we need to know which object received the message. 
      # which will allow us to control sending to only assoicated
      # connections.  Since a socket can be connected to multiple
      # WebOjects, this will have to come from the message (payload)
      # and be the id that was acted upon.
      payload = validate_payload(message)
      action        = payload.as_h.first_key
      action_params = payload[action].as_h

      case action
      when "subscribe"
        subscribe(action_params, socket)
      when "act"
        act(action_params, socket)
      else
        raise "no behavior defined for '#{action}' with parameters #{action_params}"
      end


    end

    # when a socket is closed we have to remove it from all of the subscriptions it took 
    # part in as well as from registered sessions.
    def self.on_close(socket)
      WebObject::INSTANCES.values.each &.unsubscribe(socket)
      REGISTERED_SESSIONS.delete socket.object_id
    end

  end
end
