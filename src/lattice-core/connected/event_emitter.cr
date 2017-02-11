require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    class EventEmitter

      def emit_event(event, sender)
        puts "EventEmmiter: emit_event requested by #{sender.name} for #{event.dom_item}"
        event.sender.on_event event, sender if sender != event.sender
        event.sender.class.observer.on_event event, sender  # observer handles relaying
        # sender.class.on_event event, sender      # Only to sender's class
        # self.class.on_event event, sender        # To observer class
        # sender.observers.each do |observer|
        #   observer.on_event event, sender unless observer == sender  
        # end
      end

      def self.on_event(event, sender)
        puts "EventEmiiter Class: event_emitted by #{sender.name} for #{event.dom_item}"
      end

    end
  end

end
