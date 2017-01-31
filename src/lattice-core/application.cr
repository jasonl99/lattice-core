require "./public_storage"  # this is required early so the files are loaded.
module Lattice::Core
  class Application

    # create a kemal route for every file in PublicStorage
    PublicStorage.files.each do |file|
      get file.path do |context|
        # file = PublicStorage.get(file.path)
        context.response.content_type = file.mime_type
        file.read
      end
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
