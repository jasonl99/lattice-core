module Lattice
  module Connected
    class EventHandler

     
    def send_event(event : OutgoingEvent)
      puts "Sending #{event.message} to #{event.sockets.size} sockets"
      WebSocket.send event.sockets, event.message.to_json
      event.source.observers.select {|o| o.is_a?(WebObject)}.each &.observe_event(event, event.source)
      event.source.class.observers.select {|o| o.is_a?(WebObject)}.each &.as(WebObject).observe_event(event, event.source)
    end

    def handle_event(event : IncomingEvent, target : WebObject)
      target.on_event event
      if (prop_tgt = target.propagate_event_to?)
        prop_tgt.on_event event
      end
      target.observers.select {|o| o.responds_to?(:observe_event)}.each &.observe_event(event, target)
      #target.class.observers.select {|o| o.responds_to?(:observe_event)}.each &.as(WebObject).observe_event(event, target)
      target.class.observers.each &.observe_event(event, target)
    end

    end
  end
end
