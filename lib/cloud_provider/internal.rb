
module CloudProvider
  class Internal < Base

    def initialize(configs = nil)
      @configs = configs
      self.initialize_locations if configs
    end

    def available_locations
      @configs["locations"]
        .map do |l|
          {
            str_id: l["str_id"],
            full_name: l["full_name"],
            country_fullname: l["country_fullname"],
            cloud_provider: "internal"
          }
        end
    end

    protected

  end
end
