module Lattice
  module Connected
    class ObjectList < WebObject
      alias ListType = WebObject | String
      @max_items : Int32 = 25
      property max_items : Int32 = 25
      property items : RingBuffer(ListType)
      property items_dom_id : String? # need for updating clients wth #insert

      def initialize(@name, @creator : WebObject? = nil, max_items = @max_items)
      # def initialize(@name, @creator : webobject? = nil, max_items = 25)
        @items = RingBuffer(ListType).new(size: max_items)
        @element_options["type"] = "div"
        @element_options["class"] = "object-list"
        super(@name, @creator)
      end

      def subscribed( user : Lattice::User )
        if (socket = user.socket)
          subscribed(socket)
        end
      end

      def subscribed(socket)
        puts "ObjectList (#{self.name}) subscribed sending max-children #{@max_items}"
        send_max = {"id"=>items_dom_id || dom_id,"attribute"=>"data-max-children","value"=>@max_items.to_s}
        puts "SUBSCRIBED #{send_max.class}:  #{send_max}"
        self.as(WebObject).update_attribute(send_max, [socket])
      end

      def add_content(new_content : ListType, update_sockets = true)
        @items << new_content
        # FIXME removed while testing standalone
        insert({"id"=>(items_dom_id || dom_id).as(String), "value"=>render_item new_content, @items.values.size + 1}) if update_sockets
      end

      def content
        item_content
      end

      def item_content : String
        @items.values.map_with_index {|obj, index| render_item obj, index}.join
      end

      def render_item( index : Int32)
        render_item( @items.values[index], index)
      end

      # in order of preference & flexibility, we find a way to render this object.
      def render_item(obj, index)
        val = nil
        case
        when !val && obj.responds_to?(:to_html)
          val = obj.to_html( dom_id: "#{dom_id("item")}:#{index}" )
        when !val && obj.responds_to?(:content)
          val = obj.content
        else
          val = obj.to_s
        end
        val.as(String)
      end

    end

  end
end
