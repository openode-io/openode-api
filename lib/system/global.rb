
require 'sidekiq/api'

module System
  class Global
    def self.queues_len
      Sidekiq::Stats.new.workers_size
    end
  end
end
