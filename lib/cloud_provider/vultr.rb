require "vultr"
require "countries"

Vultr.api_key = ENV[""]

module CloudProvider
  class Vultr < Base

    TYPE = "private-cloud"

    def initialize(configs)
      ::Vultr.api_key = configs["api_key"]

      initialize_locations
    end
    
    def deployment_protocol
      "ssh"
    end

    def available_locations
      # string.parameterize
      regions = ::Vultr::Regions.list
      result = regions[:result]

      result.keys
        .map do |key|
          current_location = result[key]

          country_code = result[key]["country"]
          country = ISO3166::Country.new(country_code)
          country_name = country.data["name"]

          fullname = "#{current_location["name"]} " +
            "(#{country_name}, #{current_location["continent"]})"

          {
            str_id: "#{current_location["name"]} #{current_location["DCID"]}".parameterize,
            full_name: fullname,
            country_fullname: country_name,
            cloud_provider: "vultr"
          }
        end
    end

    def plans
      return @plans if @plans

      @plans = ::Vultr::Plans.list[:result]
        .map do |key, plan|

          id = "#{plan["ram"]}-MB #{plan["VPSPLANID"]}".parameterize.upcase
          price_per_month = plan["price_per_month"].to_f

          cost_per_hour = if price_per_month * 0.10 < 3
            (price_per_month + 3.0) / 31.0 / 24.0
          else
            ((price_per_month) / 31.0 / 24.0) * 1.10
          end

          {
            id: id,
            internal_id: id,
            short_name: id,
            type: "private-cloud",
            cost_per_hour: cost_per_hour,
            cost_per_month: cost_per_hour * 31.0 * 24.0,
            VPSPLANID: plan["VPSPLANID"],
            name: plan["name"],
            vcpu_count: plan["vcpu_count"],
            ram: plan["ram"].to_i,
            disk: plan["disk"].to_f,
            bandwidth: plan["bandwidth"].to_f,
            bandwidth_gb: plan["bandwidth_gb"].to_f,
            plan_type: plan["plan_type"],
            windows: plan["windows"],
            available_locations: plan["available_locations"]
          }
        end
        .select { |plan| plan[:plan_type] == "SSD" }
    end

  end
end
