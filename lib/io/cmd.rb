require 'shellwords'

module Io
	class Cmd
		def self.sanitize_input_cmd(input)
			Shellwords.escape(input)
		end
	end
end