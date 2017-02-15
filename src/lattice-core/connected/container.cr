module Lattice
  module Connected
    abstract class Container(T) < WebObject
      @max_items : Int32 = 25
      property max_items : Int32 = 25
      property items : RingBuffer(T)
      property next_index = 0

      def next_index
        @next_index += 1
      end

      def initialize(@name, @creator : WebObject? = nil, max_items = @max_items)
      # def initialize(@name, @creator : webobject? = nil, max_items = 25)
        @items = RingBuffer(T).new(size: max_items)
        @element_type = "DIV"
        super(@name, @creator)
      end

      def subscribed(session, socket)
        send_max = {"id"=>dom_id("items"),"attribute"=>"data-maxChildren","value"=>@max_items.to_s}
        self.as(WebObject).update_attribute(send_max, [socket])
      end

      def content
        item_content
      end

      abstract def item_content

      # TODO send out dom modifications to change data-maxChildren
      # so it doesn't have to be specified in the slang file.
      # In new_content, the JSON message with id and value should have
      # max_items included.
      def add_content(new_content)
        @items << new_content
        new_content
      end


    end

  end
end
