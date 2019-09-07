
module CloudProvider
  class Internal

    def initialize(configs = nil)
      self.initialize_locations(configs) if configs
    end

    def available_locations
      
    end

    protected

    def initialize_locations(configs)
      if configs["locations"]
        configs["locations"].each do |location|
          unless Location.exists? str_id: location["str_id"]
            Rails.logger.info "Creating location #{location["str_id"]}"

            Location.create!(location)
          end
        end
      else
        Rails.logger.warn "No cloud provider internal locations."
      end
    end
  end
end
