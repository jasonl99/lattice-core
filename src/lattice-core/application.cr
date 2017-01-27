module Lattice::Core
  class Application

    get "/js/app.js" do |context|
      PublicStorage.get("/js/app.js").read
    end

    ws "/connected_object" do |socket|
      socket.on_message {|message| Lattice::Connected::WebSocket.on_message(message, socket)}
      socket.on_close   {Lattice::Connected::WebSocket.on_close(socket)}
    end

    def self.run
      Kemal.run
    end

  end
end
