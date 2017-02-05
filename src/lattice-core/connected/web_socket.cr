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



  # WebSocket is not instantiated, but acts as a conduit for connecting individual HTTP::WebSockets
  # to instantiated WebObjects.
  # 
  # REGISTERED_SESSIONS contains all known active sockets along with their associated
  # session_id in a Hash(UInt64=>String), where socket's object_id is the key, and the
  # session_id string is the value.  Ultimately, we have to be able to associated 
  # sessions with sockets, and this is the most direct means and the logical place,
  #
  # Our ClientServer API's entry point is on_message, which is called whenever a new
  # data comes in across the socket.  This data is, by definition, an aribrary string,
  # but since the endpoint is known and only promises to handle this API, we shouldn't
  # expect anything other then incoming ClientServer API messages.  
  # 
  # The incoming messages are validated and packaged by validate_payload, which does all
  # the "heavy lifting" - it identifies the instantiated object and creates a reference to it,
  # finds the associated session (if one exists) and supplies the session_id string, 
  # and pacakges those items in an object that also contains the params of the incoming messages.
  # 
  # The incoming messages, which is the ClientServer API, is a very specifically-formatted
  # object with a single key and a value object that has action and param keys.  The example
  # below shows clicking on a card in a card_game:
  # 
  #```
  # incoming messsage = {
  # "cardgame-93893329349200-card-0": {
  #   "action":"click",
  #   "params": {
  #     "src":"/images/ace_of_clubs.png" }
  # }

  SEQUENCE_DISPLAY = CardGame::Sequence.new("sequencer")
  SOCKET_LOGGER = Logger.new(File.open("./connected.log","a"))
  SOCKET_LOGGER.level = Logger::DEBUG
  SOCKET_LOGGER.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
    # io << severity[0] << ", [" << datetime << " #" << Process.pid << "] "
    # io << severity.rjust(5) << " -- " << progname << ": " << message
    io << message
  end
  SEQUENCE_LOGGER = Logger.new(File.open("./sequence.log","a"))
  SEQUENCE_LOGGER.level = Logger::DEBUG
  SEQUENCE_LOGGER.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
    # io << severity[0] << ", [" << datetime << " #" << Process.pid << "] "
    # io << severity.rjust(5) << " -- " << progname << ": " << message
    io << message
  end

  def self.shorten_socket(socket)
    "socket_#{socket.object_id.to_s[-3..-1]}"
  end

  def self.shorten_session(session_id)
    "session_#{session_id[-3..-1]}"
  end

  def self.sequence(from, to, message, detail, sender = nil)
    Lattice::Connected::SEQUENCE_LOGGER.info "#{from}->>#{to}: #{message}"
    SEQUENCE_DISPLAY.add_item(from,to, message, detail) unless sender && sender.class.to_s.split("::").last == "Sequence"
  end

  def self.log(indicator, message, level = :default)
    colorized_indicator = 
      case indicator
      when :in
        "data in".colorize(:red).on(:white)
      when :out
        "data out".colorize(:green).on(:white)
      when :process
        "process ".colorize(:light_gray).on(:dark_gray)
      when :validate
        "validate".colorize(:light_gray).on(:dark_gray)
      else
        "UNKNOWN".colorize(:white).on(:red)
      end
    Lattice::Connected::SOCKET_LOGGER.info "#{colorized_indicator} #{message}"
  end

  abstract class WebSocket


    # VALID_ACTIONS = %w(subscribe click input mouse submit)

    REGISTERED_SESSIONS = {} of UInt64=>String

    # validate_payload takes incoming message, parses it as JSON,
    # and processes it according to the ClientServer API.  The key
    # of the message is the data-item dom element that is the subject
    # of the message, and the value is an object with an action and parameters.
    # the action key of params is a string, generally maps to the javascript
    # equivalen event when possible (those used by javascripts' addEventHandler).
    # Currently, click, mouseenter, mouseleave, submit and input events are defined.
    # incoming params are not checked for validity, and their values are entirely dependent
    # on the javascript on the client (as defined in app.js).
    # Two example incoming messages are below:
    #```
    # # example subscribe message
    # {
    #   "cardgame-93972704197200": {
    #     "action":"subscribe",
    #     "params": {
    #       "session_id":"d1a602d22520ce3308427eee55376461"
    #     }
    #   }
    # }
    #
    # # example clicking a card in card_game
    # {
    #   "cardgame-93893329349200-card-0": {
    #     "action":"click",
    #     "params": {
    #       "src":"/images/ace_of_clubs.png" 
    #      }
    # }
    #```
    # Once parsed, the the key is used to identify and instantiate a WebObject,
    # If a session has previously been registered with a socket, the session_id
    # is identified.
    # These results are packaged into an object; for example, the previous
    # incoming `click` example is processed into this:
    # ```
    # {
    #   "dom_item"    => "cardgame-93893329349200-card-0 ,
    #   "session_id"  => "d1a602d22520ce3308427eee55376461",
    #   "target"      => #<CardGame::CardGame:0x56097059bf00>,
    #   "params"      => { "src":"/images/ace_of_clubs.png" }
    # }
    def self.validate_payload(message : String, socket : HTTP::WebSocket )
      return_val = JSON.parse(message)
      payload = return_val.as_h
      params = payload.first_value
      dom_item = payload.first_key
      if (session_id = REGISTERED_SESSIONS[socket.object_id]?)
        # if (session = Session.get session_id)
        #   puts "The user on this session is #{session.string?("name")}"
        # end
        log :validate, "Identified socket #{socket.object_id}"
      end
      if (data_item = self.extract_id?(dom_item))
        if (target = Lattice::Connected::WebObject::INSTANCES[data_item]?)
          # if target.subscribed? socket
          #   puts "The socket is subscribed to the target"
          # end
          log :validate, "Identified data-item #{dom_item} as #{target.class.to_s.split("::").last}-#{target.name}"
        end
      end
      result = {"dom_item"=>dom_item, "session_id"=>session_id, "target": target, "params"=>params}
      raise "Too many actions" unless payload.keys.size == 1
      result
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
    def self.register_session(session_id : String, socket : HTTP::WebSocket)
      REGISTERED_SESSIONS[socket.object_id] = session_id
      log :in, "Registered session_id #{session_id} to socket #{socket.object_id}"
      # TODO: Add note to left of socket
      #Connected.sequence "#{Lattice::Connected.shorten_socket socket}", "register_session", "#{Lattice::Connected.shorten_session session_id}"
    end

    # A socket is created at the page-level; there may be dozens of DOM objects that 
    # are subscribed to.   The socket, at its convenience, sends a _subscribe_ action
    # to the server, which contains a session_id and the dom ids for which it would like
    # to subscribe.  After the session has been verified and registered, we extract the ids
    # from subscribed_data and send the `subscribe` message with out socket to each 
    # object.
    # def self.subscribe( subscribe_data : Hash(String, JSON::Type) | Nil, socket : HTTP::WebSocket )
    #   # verify that a session exists, otherwise we don't allow a subscription
    #   return unless subscribe_data && (session = verify_session(subscribe_data["sessionID"].to_s))
    #   register_session(session.as(Session), socket)
    #   supplied_ids = extract_ids(subscribe_data["ids"].as(Array(JSON::Type)))
    #   supplied_ids.each do |id| 
    #     WebObject::INSTANCES[id].subscribe(socket)
    #   end
    #   memory_used

    # end

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
    def self.extract_id?( from : String)
      numbers = from.gsub(/[^0-9]+/,' ').squeeze(' ').strip.split(" ")
      begin
        numbers.map(&.to_u64).sort.last
      rescue
        nil
      end
    end

    # # When an incoming message arrives, it must be from a particular object that has
    # # already been subscribed to.  This processes the incoming message, determines which
    # # object should receive it, and sends it to that object.
    # def self.act ( action_data : Hash(String, JSON::Type), socket : HTTP::WebSocket )
    #   # action data is in the form of dom=>params 
    #   # FIXME this is sending subscriber_actions to all subscribed actions,
    #   # not just the one that was acted upon.
      
    #   # find the object for which the action happens
    #   if ( id = extract_id?( action_data.first_key) )
    #     acted_object = WebObject::INSTANCES[id]
    #     session_id = REGISTERED_SESSIONS[socket.object_id]?
    #     acted_object.subscriber_action(action_data, session_id)
    #   end
    #   # subscribed_to(socket).each_value do |subscribed_object|
    #   #   session_id = REGISTERED_SESSIONS[socket.object_id]?
    #   #   subscribed_object.subscriber_action(action_data, session_id)
    #   # end
    # end

    # Handle an incoming socket message
    def self.log(indicator, message, level = :default)
      colorized_indicator = case indicator
      when :in
        "Data In".colorize(:red).on(:white)
      when :out
        "Data Out".colorize(:green).on(:white)
      when :process
        "Process ".colorize(:light_gray).on(:dark_gray)
      when :validate
        "Validate".colorize(:light_gray).on(:dark_gray)
      else
        "UNKNOWN".colorize(:white).on(:red)
      end
      Lattice::Connected::SOCKET_LOGGER.info "#{colorized_indicator} #{message}"
    end

    def self.on_message(message, socket)

      payload = validate_payload(message, socket)
      log :in, "message: #{message} from socket #{socket.object_id}"
      Connected.sequence "#{Lattice::Connected.shorten_socket socket}","on_message", "Event: #{payload.first_key}", message
      # puts "payload: #{payload}.colorize(:yellow)"

      if (target = payload["target"]?)
        target = target.as(Lattice::Connected::WebObject)
        params = payload["params"].as(Hash(String,JSON::Type))
        if params["action"] == "subscribe"
          # in this case, the session_id isn't established yet, but it is in the params as session_id.
          # which came directlry from the browser (we haven't tied the two together yet
          session_id = params["params"].as(Hash(String,JSON::Type))["session_id"]?
          # REGISTERED_SESSIONS[socket.object_id] = session_id.as(String) if session_id
          register_session(session_id.as(String), socket) if session_id
          target.subscribe(socket, session_id.as(String | Nil))
        else
          session_id = payload["session_id"]?
          target.subscriber_action(payload["dom_item"].as(String), params, session_id.as(String | Nil), socket) if target.subscribed?(socket)
          #puts "Listeners for #{target.name}: #{target.listeners.map &.class.to_s}".colorize(:red)
          target.listeners.each {|listener| listener.listen_to target, payload["dom_item"].as(String), params, session_id.as(String | Nil), socket}
        end
      end

    end

    # when a socket is closed we have to remove it from all of the subscriptions it took 
    # part in as well as from registered sessions.
    def self.on_close(socket)
      log :process, "Closing socket #{socket.object_id}"
      WebObject::INSTANCES.values.each &.unsubscribe(socket)
      REGISTERED_SESSIONS.delete socket.object_id
    end

  end
end
