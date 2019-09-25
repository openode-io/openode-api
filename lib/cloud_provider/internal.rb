
module CloudProvider
  class Internal < Base

    def initialize(configs = nil)
      @configs = configs
      self.initialize_locations
      self.initialize_servers
    end

    def deployment_protocol
      
      "ssh"
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
      @configs["locations"].each do |location_item|
        location = Location.find_by! str_id: location_item["str_id"]
        raise "Missing servers" unless location_item["servers"]

        location_item["servers"].each do |server|
          location_server = LocationServer.find_by ip: server["ip"]

          unless location_server
            location_server = LocationServer.create!(location: location, ip: server["ip"])
          end

          location_server.assign_attributes(
            ram_mb: server["ram_mb"],
            cpus: server["cpus"],
            disk_gb: server["disk_gb"]
          )
          location_server.save!

          location_server.save_secret!(server)
        end
      end
    end

    def calc_cost_per_month(ram)
      amount_ram_server = 2000
      cost_server = 5.16 # in $

      nb_possible_instances = amount_ram_server.to_f / ram.to_f
      base_cost = cost_server / nb_possible_instances

      charge = base_cost * 1.50
      price = charge * 2.6

      degressive_saving = 2.0 * ram * 0.001

      price - degressive_saving
    end

    def credits_per_month(ram)
      self.calc_cost_per_month(ram) * 100 # 1 cent per credit
    end

    def plans
      [
        {
          id: "50-MB",
          name: "50MB Memory",
          short_name: "50-MB",
          ram: 50,
          storage: 1000,
          bandwidth: 100
        }
      ]
    end

    protected

  end
end
