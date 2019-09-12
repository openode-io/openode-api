
module CloudProvider
  class Internal < Base

    def initialize(configs = nil)
      @configs = configs
      self.initialize_locations
      self.initialize_servers
    end

    def available_locations
      raise "Missing locations" unless @configs["locations"]

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

    def initialize_servers
      pk = @configs["secret_key_servers"]

      @configs["locations"].each do |location|
        raise "Missing servers" unless location["servers"]

        location["servers"].each do |server|

          location_server = LocationServer.find_by ip: server["ip"]

          if location_server
            location_server
          end
        end
      end

      puts "pkkk #{pk}"
    end

    protected

  end
end
