module Str
  class Parse
    def self.integer?(str)
      str.to_i.to_s == str
    end
  end
end
