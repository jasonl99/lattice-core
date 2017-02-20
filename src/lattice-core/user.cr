module Lattice

  class UserException < Exception; end
  abstract class User

    #FIXME - We might want a REGISTERED_USERS that tie a user to a session
    # the same way is done with REGISTERED_SESSIONS in WebSocket
    
    # optimize - would it be ok to just have an array of users, and
    # use #find to get the session (which can be searched for id)

    ACTIVE_USERS = {} of String=>self  # session.id, Session instance
    # REGISTERED_SESSIONS = {} of HTTP::WebSocket=>String

    @session : Session?
    getter socket : HTTP::WebSocket?
    property last_activity = Time.now

    @subscriptions = [] of Connected::WebObject

    Session.timeout {|id| self.timeout(id)}

    def self.find_or_create(session_id : String)
      user = find?(session_id) || new(session_id)
      # user = self.find?(session_id.as(String))
      # user = new(session_id) unless user
      user.as(self)
    end

    def self.find?(session_id : String?)
      puts "Looking for #{session_id}"
      if session_id && ( u = ACTIVE_USERS[session_id]?)
        u.last_activity = Time.now
      end
      u
    end

    def socket=(socket : HTTP::WebSocket?)
      puts "Setting user socket for #{self}"
      if @socket && socket.nil? 
        on_socket_close @socket.as(HTTP::WebSocket)
        @socket.as(HTTP::WebSocket).close
      end
      @socket = socket
    end

    def on_socket_close(socket : HTTP::WebSocket? = nil)
      puts "Remove subscriptions.  Socket closing for this #{self}"
    end

    def self.socket_closed( socket : HTTP::WebSocket)
      if (  session_user = User::ACTIVE_USERS.find {|(sess,user)| user.socket == socket })
        user = session_user.last
        user.on_socket_close socket 
      end
    end

    def self.timeout(id : String)
      puts "Session timeout for session id #{id}"
      if (user = find? id)
        puts "Calling timeout for #{user}"
        user.socket = nil
        user.timeout
      end
      User::ACTIVE_USERS.delete id
    end


    abstract def load : self


    def initialize(@session : Session)
      # prepare
    end

    def initialize(session_id : String = nil)
      puts "Initializing User with session_id #{session_id}"
      if session_id && (session = Session.get(session_id))
        session = session.as(Session)
        @session = session
        ACTIVE_USERS[session.id] = self
        load
      else
        raise UserException.new "Invalid session_id '#{session_id}'"
      end
      self
    end


  end
end
