module Str
  # Encoding methods
  class Encode
    def self.strip_by(str, replacement = '', opts = {})
      if opts[:encoding] == 'ASCII'
        str.gsub(/\P{ASCII}/, replacement)
      else
        str.encode('UTF-8', invalid: :replace, undef: :replace, replace: replacement)
      end
    end

    def self.strip_invalid_chars(obj, opts = {})
      if obj.class.name == 'Hash'
        obj.each do |key, value|
          obj[key] = Encode.strip_invalid_chars(value, opts)
        end
      elsif obj.class.name == 'String'
        obj = Encode.strip_by(obj, '', opts)
      end

      obj
    end
  end
end
