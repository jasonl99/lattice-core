module Lattice
  module Connected

    # DynamicContent is a RingBuffered container whose individual items 
    # are connected WebObjects.
    # an example of this type of item would be sports scores, stock lists, etc.
    abstract class DynamicBuffer < Container(WebObject)

      def add_or_update_content( content : WebObject)
        # check to see if new_content is already 
        # in the list.  If it is, update it.  If it's not, create it.
        if @items.values.includes? content
          update_content content
        else
          add_content content
        end
      end

      def update_content(content)
        update({"id"=>content.dom_id, "value"=>content.value})
        #TODO is data-order update desirable?
        #update_attribute({"id"=>content.dom_id, "attribute"=>"data-order","value"=>"-next_index}")
        update_attribute({"id"=>content.dom_id, "attribute"=>"style","value"=>"order: #{-next_index}"})
        update({"id"=>content.dom_id, "value"=>content.value})
      end

      def add_content(content, dom_id = self.dom_id)
        @items << content
        insert({"id"=>dom_id, "value"=>content.content})
      end

      def content
        @items.values.map(&.content).join
      end
    end
  end
end
