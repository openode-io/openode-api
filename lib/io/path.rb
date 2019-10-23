# frozen_string_literal: true

module Io
  class Path
    def self.is_secure?(in_dir, file)
      File.expand_path(file.to_s, in_dir).include?(in_dir)
    end

    def self.filter_secure(in_dir, files)
      files.select { |file| Path.is_secure?(in_dir, file) }
    end
  end
end
