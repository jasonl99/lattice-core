require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    abstract class EventObserver(T) < Lattice::Connected::WebObject
      MAX_EVENTS = 25
      @@event_class = DefaultEvent

      def initialize(@name)
        @events = RingBuffer(T).new(size: MAX_EVENTS)
        super
      end

      def on_event(event : ConnectedEvent)
        puts "#{dom_id.colorize(:green).on(:white).to_s} Observed Event: #{event.colorize(:blue).on(:white).to_s}"
      end

      def observe(talker, dom_item : String, action : IncomingMessage | OutgoingMessage, session_id : String | Nil, socket : HTTP::WebSocket)
        event = T.new( talker, dom_item, action, session_id, socket)
        @events << event
        on_event event
      end

    end
  end

end
