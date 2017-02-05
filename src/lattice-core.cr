require "kemal"
require "kemal-session"
require "baked_file_system"
require "colorize"
require "./lattice-core/*"
require "./lattice-core/connected/*"

alias SocketMessage = Hash(String, String | Int32 | Hash(String, String | Int32) )

module Lattice::Core
end
