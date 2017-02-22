require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    class EventEmitter

      def emit_event(event, sender)
        puts "EventEmitter: event_emitted by #{sender.name} for #{event.dom_item} : #{event.message}"
        event.sender.on_event event, sender  unless event.sender == sender && event.direction == "Out"
        event.sender.class.observers.each &.on_event(event, sender)  # observer handles relaying
        event.sender.observers.each &.on_event(event, sender)  # observer handles relaying
      end

      def self.on_event(event, sender)
        # puts "EventEmitter Class: event_emitted by #{sender.name} for #{event.dom_item}"
      end

    end
  end

end
