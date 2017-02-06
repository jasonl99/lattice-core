require "./web_object"
module Lattice
  module Connected
    abstract class ConnectedEvent
      property sender : Lattice::Connected::WebObject
      property dom_item : String
      property action : Lattice::Connected::IncomingMessage | Lattice::Connected::OutgoingMessage
      property session_id : String?
      property socket : HTTP::WebSocket
      def initialize(@sender, @dom_item, @action, @session_id, @socket)
      end
    end
  end
end
