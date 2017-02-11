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
        super(@name, @creator)
      end

      def content
        @items.values.join
      end

      def add_content(new_content)
        @items << new_content
        new_content
      end

      # # reverse logic of child_of to find a WebObject
      # def self.find_child(dom_id : String)
      #   if (obj = INSTANCES["#{dom_id}-#{dom_id}"]? )
      #     return obj if obj.class.to_s.split("::").last == klass
      #   end
      # end

    end

  end
end
