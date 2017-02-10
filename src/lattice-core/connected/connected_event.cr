require "./web_object"
module Lattice
  module Connected
    abstract class ConnectedEvent
      property event_type : String?
      property sender : Lattice::Connected::WebObject
      property dom_item : String
      property message : Nil | ConnectedMessage | Hash(String,Hash(String,String))
      property session_id : String?
      property socket : HTTP::WebSocket?
      property direction : String
      property event_time = Time.now
      def initialize(@sender, @dom_item, @message, @session_id, @socket, @direction, @event_type = nil)
      end

      def message_value(path : String?, dig_object = @message, result=[] of JSON::Type, nodes=path.split(","), key_count = nodes.size)
        begin
          hash = dig_object.as(Hash(String,JSON::Type))
          key = nodes.shift
          result << hash.fetch(key,nil)
        rescue ex
          result << nil
        end
        unless result.last
          return result.compact.last if key_count == result.size - 1
        else
          return message_value(path: nil, dig_object: result.last, result: result, nodes: nodes, key_count: key_count)
        end
      end  
    end
  end
end
