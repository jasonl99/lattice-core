require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    abstract class EventObserver(T) < WebObject
      @max_events = 25
      @@event_class = DefaultEvent

      def initialize(@name)
        @events = RingBuffer(T).new(size: @max_events)
        super
      end

      def on_event(event : ConnectedEvent)
        puts "#{dom_id.colorize(:green).on(:white).to_s} Observed Event: #{event.colorize(:blue).on(:white).to_s}"
      end

      def observe(talker, dom_item : String, action : ConnectedMessage, session_id : String | Nil, socket : HTTP::WebSocket, direction : String)
        event = T.new( talker, dom_item, action, session_id, socket, direction)
        @events << event
        on_event event
      end

    end
  end

end
