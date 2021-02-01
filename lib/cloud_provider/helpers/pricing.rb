module CloudProvider
  module Helpers
    module Pricing
      COST_EXTRA_STORAGE_GB_PER_MONTH = 0.15
      COST_EXTRA_STORAGE_GB_PER_HOUR = COST_EXTRA_STORAGE_GB_PER_MONTH / (24 * 31)
      COST_EXTRA_BANDWIDTH_PER_GB = 0.015
      COST_EXTRA_CPU = 5.00
      COST_EXTRA_CPU_PER_HOUR = COST_EXTRA_CPU / (24 * 31)

      def calc_cost_per_month(ram)
        pricing_params = CloudProvider::Manager.instance.application['pricing']

        server_cost = pricing_params['typical_server_cost'].to_f
        allocatable_ram = pricing_params['typical_allocatable_ram'].to_f
        price_multiplier = pricing_params['price_multiplier'].to_f

        price_per_mb = server_cost / allocatable_ram

        price_per_mb * price_multiplier * ram
      end

      def credits_per_month(ram)
        calc_cost_per_month(ram) * 100 # 1 cent per credit
      end

      def calc_cost_per_hour(ram)
        calc_cost_per_month(ram) / (31.0 * 24.0)
      end

      def calc_cost_per_minute(ram)
        calc_cost_per_hour(ram) / 60.0
      end

      def self.cost_for_extra_bandwidth_bytes(nb_bytes)
        nb_bytes_in_gb = 1 * 1000 * 1000 * 1000

        (nb_bytes / nb_bytes_in_gb.to_f) * COST_EXTRA_BANDWIDTH_PER_GB
      end
    end
  end
end
