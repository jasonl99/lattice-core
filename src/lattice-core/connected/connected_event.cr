require "./web_object"
module Lattice
  module Connected

    abstract class ConnectedEvent
      property event_type : String?
      property sender : Lattice::Connected::WebObject
      property user : Lattice::User?
      property dom_item : String
      property message : Nil | ConnectedMessage | Hash(String,Hash(String,String))
      property direction : String
      property event_time = Time.now

      def initialize(@sender, @dom_item, @message, @direction, @event_type = nil, @user = nil)
      end

      def message_value(path : String?, dig_object = @message, result=[] of JSON::Type, nodes=path.split(","), key_count = nodes.size)
        begin
          hash = dig_object.as(Hash(String,JSON::Type))
          key = nodes.shift
          result << hash.fetch(key,nil)
        rescue ex
          result << nil
        end
        unless result.last
          return result.compact.last if key_count == result.size - 1
        else
          return message_value(path: nil, dig_object: result.last, result: result, nodes: nodes, key_count: key_count)
        end
      end  
    end


    alias Message = Hash(String,JSON::Type)

    abstract class Event
      property created = Time.now
      def debug(str)
        puts "#{self.class}: #{str}".colorize(:blue).on(:white)
      end
    end

    class UserEvent < Event
      property user : Lattice::User
      property input : String
      property? message : Message?
      property? error : Message?

      def initialize(@input, @user)
        begin
          @message = JSON.parse(@input).as_h
          debug "UserEvent #{@message} created with #{@input} for #{@user}"
        rescue
          error = Message.new
          error["error"] = "could not convert incoming message to JSON"
          error["source"] = @input
          error["user"] = @user.to_s
          @error = error
          debug "Error creating UserEvent: #{@error}"
        end
        incoming_event if valid?
      end

      def valid?
        !@error
      end

      def incoming_event
        if (message = @message)
          data = message.values.first.as(Message)
          action = data["action"].as(String)
          params = data["params"].as(Message)
          IncomingEvent.new(
            user: @user,
            dom_item: message.keys.first,
            action: action,
            params: params
          )
        end
      end

    end

    class IncomingEvent < Event
      property user : Lattice::User
      property action : String?
      property params : Message
      property component : String?
      property index : Int32?
      @dom_item : String

      #OPTIMIZE
      # create ClickEvent, InputEvent where
      # params are further refined
      def initialize(@user, @dom_item, @action, @params)

        debug "New IncomingEvent #{@dom_item} #{@action} #{@params} refers to #{web_object}"
        if (target = web_object)
          @component = target.component_id(@dom_item)
          @index = target.component_index(@dom_item)
          target.handle_event(self)
        end
      end

      # returns the instantiated web object for this item
      def web_object
        if (dom = @dom_item)
          WebObject.from_dom_id(dom)
        end
      end


    end




    class OutgoingEvent < Event
      property message : Message
      property sockets : Array(HTTP::WebSocket)
      def initialize(@message, @sockets)
      end
    end

    class InternalEvent < Event
    end

  end
end
