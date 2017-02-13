module Lattice
  class RingBuffer(T)
    property current_index = -1
    property size : Int32 = 10

    def initialize(size : Int32 = nil)
      if size
        @size = size.as(Int32)
      else
        @size = 25
      end
      @storage = Array(T | Nil).new(@size,nil)
    end

    def storage
      @storage
    end

    # translates the index (an absolute position) into
    # the ring-buffered equivalent so data can be accessed directly
    # as if it were a regular array
		def calculated_position(index : Int32)
  		(index + @current_index + 1) % @size
    end

		def delete_at( index : Int32)
  		position = calculated_position(index)
      puts "ci: #{@current_index} delete at #{index} position #{position} for #{storage}"
  		@storage.delete_at position
  		@current_index -= 1 if position <= @current_index
  		@storage << nil
      puts "after delete_at #{@storage}"
		end

    def delete(val : T)
      if (pos = @storage.index(val))
        @storage.delete(val)
        @storage << nil
	  		@current_index -= 1 if position <= @current_index
      end
    end

    def []=(index,val)
      @storage[calculated_position index] = val
    end

    def [](index)
      @storage[calculated_position index]
    end

    def <<(val : T)
      @current_index = (@current_index + 1) % @size
      @storage[@current_index] = val
    end

    def values
      (@storage[@current_index + 1..-1] + @storage[0..@current_index]).compact
    end

  end
end
