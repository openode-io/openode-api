require "vultr"
require "countries"

Vultr.api_key = ENV[""]

module CloudProvider
  class Vultr

    def initialize(configs)
      puts "init vultr #{configs.inspect}"
      ::Vultr.api_key = configs["api_key"]
    end

    def available_locations

      # string.parameterize
      regions = ::Vultr::Regions.list
      result = regions[:result]
      puts "regions keys ? #{result.keys.inspect}"

      rr = result.keys
        .map do |key|
          {
            str_id: "#{result[key]["name"]} #{result[key]["id"]}".parameterize,
            
          }
        end

      puts "rr -> #{rr.inspect}"

      rr
    end

  end
end
