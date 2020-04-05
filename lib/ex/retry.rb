module Ex
  class Retry
    def self.n_times(args = {})
      args[:nb_trials].times do |index|
        return yield index
      rescue StandardError => e
        # if it's still failing after N times, throw exception
        raise e if index == args[:nb_trials] - 1

        sleep args[:sleep_n] if args[:sleep_n]
      end
    end
  end
end
