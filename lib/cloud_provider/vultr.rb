require "vultr"

Vultr.api_key = "your_api_key"

module CloudProvider
  class Vultr

    def initialize(configs)
      puts "init vultr"
    end

    def locations

      regions = Vultr::Regions.list
    end

  end
end
