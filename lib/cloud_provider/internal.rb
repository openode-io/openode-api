
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

    def calc_cost_per_hour(ram)
      self.calc_cost_per_month(ram) / (31.0*24.0)
    end

    def calc_cost_per_minute(ram)
      self.calc_cost_per_hour(ram) / 60.0
    end

    def plans
      list = [
        {
          id: "sandbox",
          internal_id: "free",
          name: "Sandbox",
          ram: 100,
          storage: 1000,
          bandwidth: 10
        },
        {
          id: "50-MB",
          internal_id: "first",
          name: "50MB Memory",
          ram: 50,
          storage: 1000,
          bandwidth: 100
        },
        {
          id: "100-MB",
          internal_id: "second",
          name: "100MB Memory",
          ram: 100,
          storage: 1000,
          bandwidth: 200
        },
        {
          id: "200-MB",
          internal_id: "third",
          name: "200MB Memory",
          ram: 200,
          storage: 1000,
          bandwidth: 400
        },
        {
          id: "500-MB",
          internal_id: "fourth",
          name: "500MB Memory",
          ram: 500,
          storage: 1000,
          bandwidth: 1000
        },
        {
          id: "1-GB",
          internal_id: "fifth",
          name: "1GB Memory",
          ram: 1024,
          storage: 1000,
          bandwidth: 2000
        },
        {
          id: "2-GB",
          internal_id: "sixth",
          name: "2GB Memory",
          ram: 2048,
          storage: 1000,
          bandwidth: 4000
        }
      ]

      list.map do |plan|
        plan[:short_name] = plan[:id]
        plan[:human_id] = plan[:id]
        plan[:cost_per_minute] = self.calc_cost_per_minute(plan[:ram])
        plan[:cost_per_hour] = self.calc_cost_per_hour(plan[:ram])
        plan[:cost_per_month] = self.calc_cost_per_month(plan[:ram])

        plan
      end
    end

    protected

  end
end
