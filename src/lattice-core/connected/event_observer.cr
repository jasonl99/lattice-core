require "./web_object"
require "./connected_event"
module Lattice
  module Connected
    class EventObserver

      # Relay the event to the EventObserver class (broadcast)
      # Relay the event to the sender's class (mediumcast)
      # Relay teh event to the listners (narrowcast)
      def on_event(event : ConnectedEvent, sender)
        # puts "EventObserver: event reported by #{sender.name} for #{event.dom_item}"
        event.sender.on_event event, sender if event.direction == "In"
        sender.class.on_event event, sender      # Only to sender's class
        self.class.on_event event, sender        # To observer class
        sender.observers.each do |observer|
          observer.on_event event, sender        #To individual observers
        end
      end

      def self.on_event(event, sender)
        puts "EventObserver Class: event reported by #{sender.name} for #{event.dom_item}"
      end


    end
  end

end
