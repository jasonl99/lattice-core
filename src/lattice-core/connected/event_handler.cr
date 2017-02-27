module Lattice
  module Connected
    class EventHandler

     def handle_event(event : IncomingEvent, target : WebObject)
        target.on_event event
        if (prop_tgt = target.propagate_event_to?)
          prop_tgt.on_event event
        end
        target.observers.select {|o| o.is_a?(WebObject)}.each &.observe_event(event, target)
        target.class.observers.select {|o| o.is_a?(WebObject)}.each &.as(WebObject).observe_event(event, target)

        # unless event.sender == sender && event.direction == "Out"
        #   event.sender.on_event event, sender  unless event.sender == sender && event.direction == "Out"
        # end
        # event.sender.propagate(event) if event.direction == "In"

        # event.sender.class.observers.each &.on_event(event, sender)  # observer handles relaying
        # event.sender.observers.each &.on_event(event, sender)  # observer handles relaying
      end

    end
  end
end
