require 'uri'

module Io
  # Path
  class Path
    def self.secure?(in_dir, file)
      File.expand_path(file.to_s, in_dir).include?(in_dir)
    end

    def self.filter_secure(in_dir, files)
      files.select { |file| Path.secure?(in_dir, file) }
    end

    def self.valid?(path)
      URI.parse(path)&.path&.present?
    rescue StandardError
      false
    end
  end
end
