module Lattice
  module Connected
    abstract class Container(T) < WebObject
      @max_items : Int32 = 25
      property max_items : Int32 = 25
      property items : RingBuffer(T)
      property next_index = 0
      property items_dom_id : String?

      def next_index
        @next_index += 1
      end

      def initialize(@name, @creator : WebObject? = nil, max_items = @max_items)
        @items = RingBuffer(T).new(size: max_items)
        @element_options["type"] = "DIV"
        super(@name, @creator)
      end

      def subscribed(session, socket)
        send_max = {"id"=>dom_id("items"),"attribute"=>"data-maxChildren","value"=>@max_items.to_s}
        self.as(WebObject).update_attribute(send_max, [socket])
      end

      def add_content(new_content : T, update_sockets = true)
        @items << new_content
        insert({"id"=>items_dom_id || dom_id, "value"=>new_content}) if update_sockets
      end

      def to_html
        open_tag + content + close_tag
      end

      def content
        item_content
      end

      def item_content
        @items.values.map(&.to_s).join("\n")
      end

    end

  end
end
