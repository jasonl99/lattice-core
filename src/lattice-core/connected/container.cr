module Lattice
  module Connected
    abstract class Container(T) < WebObject
      @max_items : Int32 = 25
      property items : RingBuffer(T)

      def initialize(@name, @creator : WebObject? = nil)
        @items = RingBuffer(T).new(size: @max_items)
        super
      end


    end

  end
end
