module Lattice
  module Connected
    abstract class Container(T) < WebObject
      @max_items : Int32 = 25
      property child_class = T
      property items : RingBuffer(T)

      def initialize(@name, @creator : WebObject? = nil)
        @items = RingBuffer(T).new(size: @max_items)
        super
      end


      # reverse logic of child_of to find a WebObject
      def self.find_child(dom_id : String)
        if (obj = INSTANCES["#{dom_id}-#{dom_id}"]? )
          return obj if obj.class.to_s.split("::").last == klass
        end
      end

      def self.child_of(creator : WebObject)
        obj = new(name: "#{creator.dom_id}-#{dom_id}")
        obj.creator = creator
        obj
      end


    end

  end
end
