module Str
  # Encoding methods
  class Encode
    def self.strip_by(str, replacement = '')
      str.encode('UTF-8', invalid: :replace, undef: :replace, replace: replacement)
    end

    def self.strip_invalid_chars(obj)
      if obj.class.name == 'Hash'
        obj.each do |key, value|
          obj[key] = Encode.strip_invalid_chars(value)
        end
      elsif obj.class.name == 'String'
        obj = Encode.strip_by(obj)
      end

      obj
    end
  end
end
