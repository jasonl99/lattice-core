require "digest/sha1"
class Base62

  class ArgumentError < Exception; end
  ALPHABET = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
  BASE = ALPHABET.size.to_u64

  # Creates a base62 digest of a given string.
  # ```
  # string_digest = Base62.string_digest("Hi Bob")  # "a8t1hFHyM"`
  # string_digest = Base62.string_digest("Hi Bob")  # 2213222356800000
  # 
	def self.string_digest( target : String) : String
    sha_digest = Digest::SHA1.digest target
    sd = shorten_digest(sha_digest)
    encode sd
  end

  # returns the UInt64 equivalent
  def self.int_digest( target : String) : UInt64
      sha_digest = Digest::SHA1.digest target
    	sd = shorten_digest(sha_digest)
      puts "Calculating int_digest for #{target} with sd #{sd}".colorize(:blue).on(:white)
      return sd
	end


  def self.shorten_digest( digest : StaticArray(UInt8,20))
    puts "All values: #{digest}".colorize(:blue).on(:white)
    values = digest.first(8).map_with_index do | unit, index |
      index == 0 ? unit : (BASE ** index) * unit
    end	
    puts "Values: #{values}".colorize(:blue).on(:white)
    values.sum
  end

  def self.encode( big_int : UInt64) : String
    multiples = [] of UInt32
    while (big_int > BASE)
      multiples << (big_int % BASE).to_u32
      big_int = (big_int / BASE  )			
    end
    multiples << big_int.to_u32
    multiples.reverse.map {|at_pos| ALPHABET[at_pos]}.join("").as(String)
  end

  def self.decode ( encoded : String)
    multiples = encoded.split("").map {|char| ALPHABET.index(char).as(Int32).to_u64}.reverse
    values = multiples.map_with_index do | unit, index |
      index == 0 ? unit : (BASE ** index) * unit
    end	
    values.sum
  end

  
end

