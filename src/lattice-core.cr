require "kemal"
require "kemal-session"
require "baked_file_system"
require "colorize"
require "logger"
require "kilt/slang"
require "./lattice-core/*"


class Session
  def self.before_destroy(id : String)
    puts "Session #{id} is about to be destroyed!".colorize(:red).on(:white)
    expired = Lattice::Connected::WebSocket::REGISTERED_SESSIONS.find do |socket,session_id| 
      # puts "Found session's socket, removing from REGISTERED_SESSIONS".colorize(:blue).on(:white)
      # Connected::WebSocket::REGISTERED_SESSIONS.delete socket
      session_id == id
    end
    if expired
      puts "Found session's socket, removing from REGISTERED_SESSIONS".colorize(:blue).on(:white)
      Lattice::Connected::WebSocket::REGISTERED_SESSIONS.delete expired.first
    end
  end
end

module Lattice::Core
end
