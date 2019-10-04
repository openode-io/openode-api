module Ex
	class Logger
		def self.out(level, exception, msg = nil)
			Rails.logger.send(level, "----------------------------------------------")
			Rails.logger.send(level, "-- Exception --")
			Rails.logger.send(level, "- Level: #{level}")
			Rails.logger.send(level, "- Message (specific): #{msg}") if msg
			Rails.logger.send(level, "- Message (exception): #{exception.message}")

			Rails.logger.send(level, exception.backtrace.join("\n")) if exception.backtrace
		end

		def self.info(exception, msg = nil)
			Logger.out("info", exception, msg)
		end
	end
end