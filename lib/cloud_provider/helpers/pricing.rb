module CloudProvider
  module Helpers
    module Pricing
      COST_EXTRA_STORAGE_GB_PER_MONTH = 0.13
      COST_EXTRA_STORAGE_GB_PER_HOUR = COST_EXTRA_STORAGE_GB_PER_MONTH / (24 * 31)
      COST_EXTRA_CPU = 5.00
      COST_EXTRA_CPU_PER_HOUR = COST_EXTRA_CPU / (24 * 31)

      def calc_cost_per_month(id, ram)
        return 0 if id == Website::OPEN_SOURCE_ACCOUNT_TYPE

        amount_ram_server = 2000
        cost_server = 5.16 # in $

        nb_possible_instances = amount_ram_server.to_f / ram
        base_cost = cost_server / nb_possible_instances

        charge = base_cost * 1.50
        price = charge * 2.6

        degressive_saving = 2.0 * ram * 0.001

        price - degressive_saving
      end

      def credits_per_month(id, ram)
        calc_cost_per_month(id, ram) * 100 # 1 cent per credit
      end

      def calc_cost_per_hour(id, ram)
        calc_cost_per_month(id, ram) / (31.0 * 24.0)
      end

      def calc_cost_per_minute(id, ram)
        calc_cost_per_hour(id, ram) / 60.0
      end
    end
  end
end
