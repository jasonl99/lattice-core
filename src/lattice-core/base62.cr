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
    encode sha_digest.first(8).reduce(1_u64) {|o,i| o*i}
  end

  # returns the UInt64 equivalent
  def self.int_digest( target : String) : UInt64
      sha_digest = Digest::SHA1.digest target
    	int_dig = sha_digest.first(8).reduce(1_u64) {|o,i| o*i}
      puts "first 8 sha digest: #{sha_digest.first(8)}"
      puts "calculating int_digest for #{target} #{target}"
      int_dig
	end

  # decodes a string_digest to an int
  def self.decode(base_val : String) : UInt64
    int_val = 0_u64
    base_val.reverse.split(//).each_with_index do |char,index|
      raise ArgumentError.new "Value passed not a valid Base58 String." unless ALPHABET.index(char)
      int_val +=( ALPHABET.index(char).as(Int32).to_u64 *   BASE**(index)  ).to_u64 
    end
    int_val
  end

  # encodes UInt64 into a base62 string
  def self.encode(int_val : UInt64) : String
    base_val = ""
    while(int_val >= BASE)
      mod = int_val % BASE
      base_val = ALPHABET[mod,1] + base_val
      int_val = (int_val - mod)/BASE
    end
    ALPHABET[int_val,1] + base_val
  end
  
  
end

