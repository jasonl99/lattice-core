module Lattice

  class UserException < Exception; end
  abstract class User

    #FIXME - We might want a REGISTERED_USERS that tie a user to a session
    # the same way is done with REGISTERED_SESSIONS in WebSocket
    
    # optimize - would it be ok to just have an array of users, and
    # use #find to get the session (which can be searched for id)

    ACTIVE_USERS = {} of String=>self
    # REGISTERED_SESSIONS = {} of HTTP::WebSocket=>String

    @session : Session?
    getter socket : HTTP::WebSocket?
    property last_activity = Time.now

    @subscriptions = [] of Connected::WebObject

    # commenting out timeout to see if this is the cause of the SSL ZERO thing
    Session.timeout {|id| self.timeout(id)} 

    def self.find_or_create(session_id : String)
      user = find?(session_id) || new(session_id)
      # user = self.find?(session_id.as(String))
      # user = new(session_id) unless user
      user.as(self)
    end

    def self.find?(session_id : String?)
      if session_id && ( u = ACTIVE_USERS[session_id]?)
        u.last_activity = Time.now
      end
      u
    end

    def socket=(socket : HTTP::WebSocket)
      @socket = socket
    end

    def self.socket_closing( socket : HTTP::WebSocket)
      puts "User.socket_closing called".colorize(:dark_gray).on(:white)
      if (key_value = ACTIVE_USERS.find {|(k,u)| u.socket == socket} )
        user = key_value.last.as(User)
        user.close_socket
      end
    end

    def close_socket
      puts "user #{self} close_socket called".colorize(:dark_gray).on(:white)
      return unless @socket
      on_socket_close
      # @socket.as(HTTP::WebSocket).close
      # @socket = nil
    end

    def on_socket_close
      puts "Remove subscriptions.  Socket closing for this #{self}"
    end

    def self.timeout(id : String)
      puts "Session timeout for session id #{id}".colorize(:dark_gray).on(:white)
      if (user = find? id)
        puts "Calling timeout for #{user}"
        if (socket = user.socket)
          puts "Calling WebSocket.close".colorize(:dark_gray).on(:white)
          Connected::WebSocket.close(socket) 
        end
        user.timeout
      end
      User::ACTIVE_USERS.delete id
      puts "Users remaining #{ACTIVE_USERS.size}"
    end


    abstract def load : self


    def initialize(@session : Session)
      # prepare
    end

    def initialize(session_id : String = nil)
      if session_id && (session = Session.get(session_id))
        session = session.as(Session)
        @session = session
        ACTIVE_USERS[session.id] = self
        load
      # else
      #   raise UserException.new "Invalid session_id '#{session_id}'"
      end
      self
    end


  end
end
