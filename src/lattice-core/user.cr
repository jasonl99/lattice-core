module Lattice

  class UserException < Exception; end
  abstract class User

    ACTIVE_USERS = {} of String=>self

    @session : Session?
    property socket : HTTP::WebSocket?
    property last_activity = Time.now
    @subscriptions = [] of Connected::WebObject

    Session.timeout {|id| self.timeout(id)} 

    def initialize(@session : Session, @socket : HTTP::WebSocket)
      prepare
    end

    def initialize(@session : Session)
      prepare
    end

    def initialize(session_id : String = nil)
      if session_id && (session = Session.get(session_id))
        prepare
        @session = session
        ACTIVE_USERS[session.id] = self
      else
        
        # the user will be created, but not persisted (it won't be added to ACTIVE_USERS
        # but any attempt to access things inside the session will cause an exception
      end
      self
    end

    # TODO create a find_or_create with Session type, pass it in directly?
    def self.find_or_create(session_id : String)
      user = find?(session_id) || new(session_id)
      # user = self.find?(session_id.as(String))
      # user = new(session_id) unless user
      user.as(self)
    end

    def self.find?(session_id : String?)
      if session_id && ( u = ACTIVE_USERS[session_id]?)
        u.last_activity = Time.now
        u.as(self)
      end
    end


    def session?
      @session
    end

    def session
      @session.as(Session)
    rescue
      raise UserException.new "Attempt to access a nil @session in #{self.class}."
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

    # basically sets @socket to nil so it can be gc'ed by Crystal
    def close_socket
      puts "user #{self} close_socket called".colorize(:dark_gray).on(:white)
      return unless @socket
      on_socket_close
      # @socket.as(HTTP::WebSocket).close
      @socket = nil
    end

    def on_socket_close
      puts "Remove subscriptions.  Socket closing for this #{self}"
    end

    # called by #self.timeout when the given id has expired
    def timeout
    end
  
    def self.timeout(id : String)
      puts "Session timeout for session id #{id}".colorize(:dark_gray).on(:white)
      if (user = find? id)
        puts "Calling timeout for #{user}"
        puts "user.socket: #{user.socket}"
        if (socket = user.socket)
          puts "Calling WebSocket.close".colorize(:dark_gray).on(:white)
          user.close_socket
          Connected::WebSocket.close(socket) 
        end
        user.timeout
      end
      User::ACTIVE_USERS.delete id
      puts "Users remaining #{ACTIVE_USERS.size}"
    end

    def prepare
      if @session
        session = @session.as(Session)
        @session = session
        session.string("last_activity", Time.now.to_s)
      end
      load
    end

    abstract def save : self
    abstract def load : self

  end
end
