require 'yaml'

module Io
  # Cmd input utils
  class Yaml
    def self.valid?(input)
      YAML.safe_load(input)

      true
    rescue StandardError => e
      Rails.logger.error(e)

      false
    end
  end
end
