
module CloudProvider
  class Base

    def initialize(configs = nil)

    end

    def initialize_locations
      locations = self.available_locations

      locations.each do |l|
        unless Location.exists?(str_id: l[:str_id])
          Rails.logger.info "Creating location #{l.inspect}"
          Location.create!(l)
        end
      end
    end

    protected
  end
end
