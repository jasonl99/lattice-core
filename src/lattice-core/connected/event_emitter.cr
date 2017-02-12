require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    class EventEmitter

      def emit_event(event, sender)
        # puts "EventEmmiter: emit_event #{event.event_type} requested by #{sender.name} for #{event.dom_item} regarding #{event.sender.name}"
        # puts "#{event.message}" if event.dom_item
        event.sender.on_event event, sender  if event.direction == "In"
        event.sender.class.observers.each &.on_event(event, sender)  # observer handles relaying
        event.sender.observers.each &.on_event(event, sender)  # observer handles relaying
      end

      def self.on_event(event, sender)
        puts "EventEmiiter Class: event_emitted by #{sender.name} for #{event.dom_item}"
      end

    end
  end

end
