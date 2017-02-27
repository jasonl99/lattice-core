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
      end

    end
  end
end
