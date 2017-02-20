module Lattice

  class UserException < Exception; end
  abstract class User

    #FIXME - We might want a REGISTERED_USERS that tie a user to a session
    # the same way is done with REGISTERED_SESSIONS in WebSocket
    
    # optimize - would it be ok to just have an array of users, and
    # use #find to get the session (which can be searched for id)

    @session : Session?
    ACTIVE_USERS = {} of String=>self  # session.id, Session instance
    # REGISTERED_SESSIONS = {} of HTTP::WebSocket=>String


    Session.timeout {|id| self.timeout(id)}

    def self.find_or_create(session_id : String?)
      session_id = session_id.as(String)
      user = self.find?(session_id) || new(session_id) # self.as(self.class).new(session_id)
      user
    end

    def self.find?(session_id : String?)
      puts "Looking for #{session_id}"
      if session_id && ( u = ACTIVE_USERS[session_id]?)
        u.load
      end
      u
    end

    def self.timeout(id : String)
      puts "Session timeout for session id #{id}"
      if (user = find? id)
        puts "Calling timeout for #{user}"
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
