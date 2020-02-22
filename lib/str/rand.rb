module Str
  # Encoding methods
  class Rand
    def self.password
      SecureRandom.hex(2) +
        rand(65..90).chr.upcase +   # upper case
        SecureRandom.hex(2) +
        rand(65..90).chr.downcase + # a lower case
        rand.to_s[2..].first # a digit
    end
  end
end
