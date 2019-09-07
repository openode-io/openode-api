require "vultr"
require "countries"

Vultr.api_key = ENV[""]

module CloudProvider
  class Vultr < Base

    def initialize(configs)
      ::Vultr.api_key = configs["api_key"]

      initialize_locations
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

  end
end
