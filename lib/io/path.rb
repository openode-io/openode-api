
module Io
  class Path
    def self.is_secure?(in_dir, file)
    	puts "== #{File.expand_path("#{file}", in_dir).include?(in_dir)}"
    	File.expand_path("#{file}", in_dir).include?(in_dir)
    end
  end
end
