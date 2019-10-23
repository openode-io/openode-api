# frozen_string_literal: true

require 'shellwords'

module Io
  class Cmd
    def self.sanitize_input_cmd(input)
      Shellwords.escape(input)
                .gsub('\\ ', ' ')
    end
  end
end
