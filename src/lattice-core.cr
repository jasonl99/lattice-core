require "kemal"
require "kemal-session"
require "baked_file_system"
require "colorize"
require "logger"
require "kilt/slang"
require "./lattice-core/*"

{% if Crystal::VERSION == "0.21.0" %}
  puts "Crystal version: #{Crystal::VERSION}"
  require "./lattice-core/hotfixes/gzip_header"
{% end  %}

# Session.destroy(id) do
#   puts "Session #{id} is about to be destroyed!".colorize(:red).on(:white)
#   expired = Lattice::Connected::WebSocket::REGISTERED_SESSIONS.find do |socket,session_id| 
#     session_id == id
#   end
#   if expired
#     puts "Found session's socket, removing from REGISTERED_SESSIONS".colorize(:blue).on(:white)
#     Lattice::Connected::WebSocket::REGISTERED_SESSIONS.delete expired.first
#   end
# end

# class Session
#   def self.before_destroy(id : String)
#     puts "Session #{id} is about to be destroyed!".colorize(:red).on(:white)
#     expired = Lattice::Connected::WebSocket::REGISTERED_SESSIONS.find do |socket,session_id| 
#       session_id == id
#     end
#     if expired
#       puts "Found session's socket, removing from REGISTERED_SESSIONS".colorize(:blue).on(:white)
#       Lattice::Connected::WebSocket::REGISTERED_SESSIONS.delete expired.first
#     end
#   end
# end

module Lattice::Core
end
