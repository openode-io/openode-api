module CloudProvider
  class GcloudRun < Base
    TYPE = 'gcloud'
    COST_EXTRA_CPU = 5.00
    COST_EXTRA_CPU_PER_HOUR = COST_EXTRA_CPU / (24 * 31)

    def initialize(configs = nil)
      @configs = configs
      initialize_locations
    end

    def deployment_protocol
      'ssh'
    end

    def type
      TYPE
    end

    def limit_resources?
      true
    end

    def stop(options = {})
      # nothing special to do
    end

    def available_locations
      raise 'Missing locations' unless @configs['locations']

      @configs['locations']
        .map do |l|
          {
            str_id: l['str_id'],
            full_name: l['full_name'],
            country_fullname: l['country_fullname'],
            cloud_provider: 'internal'
          }
        end
    end

    def calc_cost_per_month(ram)
      amount_ram_server = 2000
      cost_server = 5.16 # in $

      nb_possible_instances = amount_ram_server.to_f / ram
      base_cost = cost_server / nb_possible_instances

      charge = base_cost * 1.50
      price = charge * 2.6

      degressive_saving = 2.0 * ram * 0.001

      price - degressive_saving
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

    def plans
      list = [
        {
          id: 'open-source',
          internal_id: Website::OPEN_SOURCE_ACCOUNT_TYPE,
          name: 'Open Source',
          ram: 128,
          storage: 1000,
          bandwidth: 10
        },
        {
          id: '128-MB',
          internal_id: 'grun-128',
          name: '128MB Memory (On Demand)',
          ram: 128,
          storage: 1000,
          bandwidth: 200
        },
        {
          id: '256-MB',
          internal_id: 'grun-256',
          name: '200MB Memory (On Demand)',
          ram: 200,
          storage: 1000,
          bandwidth: 400
        },
        {
          id: '512-MB',
          internal_id: 'grun-512',
          name: '512MB Memory (On Demand)',
          ram: 512,
          storage: 1000,
          bandwidth: 1000
        },
        {
          id: '1-GB',
          internal_id: 'grun-1000',
          name: '1GB Memory (On Demand)',
          ram: 1024,
          storage: 1000,
          bandwidth: 2000
        },
        {
          id: '2-GB',
          internal_id: 'grun-2000',
          name: '2GB Memory (On Demand)',
          ram: 2048,
          storage: 1000,
          bandwidth: 4000
        },
        {
          id: 'auto',
          internal_id: 'auto',
          name: 'Auto (Subscription)',
          ram: 2048,
          storage: 1000,
          bandwidth: 2000
        }
      ]

      list.map do |plan|
        plan[:short_name] = plan[:id]
        plan[:human_id] = plan[:id]
        plan[:cost_per_minute] = calc_cost_per_minute(plan[:ram])
        plan[:cost_per_hour] = calc_cost_per_hour(plan[:ram])
        plan[:cost_per_month] = calc_cost_per_month(plan[:ram])
        plan[:type] = TYPE

        plan
      end
    end

    def plans_at(_any_location)
      plans
    end
  end
end
