require "./user"
module Lattice

  class BasicUser < User

    def load
      puts "Load user data here or override"
    end
    
    def save
      puts "Save user data here or override"
    end
  end

end
