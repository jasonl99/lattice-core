module Lattice
  module Connected

    # StableContent is a RingBuffered container whose individual items 
    # are static, but the items themselves roll through the ring buffer.
    # A good example is the shell program `tail` where you want to see
    # the latest x items in a list (a log file, a list of events, chat messages, etc)
    abstract class StaticBuffer < Container(String)
      def add_content( new_content : String, dom_id : String? = self.dom_id("items"))
        @items << new_content
        insert({"id"=>dom_id, "value"=>new_content})
      end
      def item_content
        @items.values.join
      end
    end
  end
end
