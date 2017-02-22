require "./public_storage"  # this is required early so the files are loaded.

module Lattice::Core
  class Application

    @@socket_path : String?

    # create a kemal route for every file in PublicStorage
    PublicStorage.files.each do |file|
      get file.path do |context|
        context.response.content_type = file.mime_type
        file.read
      end
    end

    def self.route_socket(user_class = Lattice::BasicUser, path = "/connected_object" )
      @@socket_path = path
      ws(path) do |socket, ctx|
        session = Session.new(ctx)
        user = user_class.new(session, socket)

        socket.on_message do |message| 
          Lattice::Connected::WebSocket.on_message(message, socket, user)
        end

        socket.on_close do
          # Pass on notification of socket so we can handle it 
          Lattice::Connected::WebSocket.on_close(socket, user)
        end
      end
    end

    def self.run
      route_socket unless @@socket_path  # set up the default socket path
      puts "Running kemal"
      Kemal.run
    end

  end
end
