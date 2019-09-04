
module Io
  class Path
    def self.is_secure?(in_dir, file)
      File.expand_path("#{file}", in_dir).index(in_dir) == 0
    end
  end
end
