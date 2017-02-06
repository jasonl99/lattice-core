require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    abstract class EventObserver(T) < Lattice::Connected::WebObject
      MAX_EVENTS = 25
      @events = RingBuffer(T).new(size: MAX_EVENTS)

      def observe(talker, dom_item, action, session_id, socket)
        event = DefaultEvent.new( talker, dom_item, action, session_id, socket)
        @events << event
        super
      end

    end
  end

end
