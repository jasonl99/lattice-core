module Lattice::Connected

  class TooManySessions < Exception; end
  class UserException < Exception; end

  abstract class WebSocket

    @@max_sessions = 100_000 # I have absolutely no idea what this number and or should be.

    def self.close(socket)
     socket.close 
      WebObject::INSTANCES.values.each do |web_object|
        web_object.unsubscribe(socket)
      end
      User.socket_closing(socket)
    end

    def self.send(sockets : Array(HTTP::WebSocket), msg)
      sockets.each do |socket|
        socket.send(msg) unless socket.closed?
      end
    end

    def self.on_message(message : String, socket : HTTP::WebSocket, user : Lattice::User)
      UserEvent.new(message, user)
    end

    def self.on_close(socket : HTTP::WebSocket, user : Lattice::User)
      WebObject::INSTANCES.values.each do |web_object|
        web_object.unsubscribe(socket)
      end
      User.socket_closing(socket)
     end

  end
end
