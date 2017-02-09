require "./web_object"
module Lattice
  module Connected
    abstract class ConnectedEvent
      property event_type : String?
      property sender : Lattice::Connected::WebObject
      property dom_item : String
      property action : Nil | ConnectedMessage | Hash(String,Hash(String,String))
      property session_id : String?
      property socket : HTTP::WebSocket
      property direction : String
      property event_time = Time.now
      def initialize(@sender, @dom_item, @action, @session_id, @socket, @direction, @event_type = nil)
      end
    end
  end
end
