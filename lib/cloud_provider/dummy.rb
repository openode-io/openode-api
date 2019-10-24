module CloudProvider
  class Dummy < Base
    def initialize(configs); end

    def type
      'dummy'
    end

    def available_locations
      [
        {
          id: 'canada3',
          name: 'Toronto (Canada)',
          country_fullname: 'Canada3'
        }
      ]
    end

    def plans
      [
        {
          id: 'DUMMY-PLAN',
          internal_id: 'dummy',
          name: 'Dummy Memory',
          ram: 100,
          storage: 1000,
          bandwidth: 200,
          short_name: 'dummy',
          human_id: 'dummy',
          cost_per_minute: 0.000018060035842293905,
          cost_per_hour: 0.0010836021505376344,
          cost_per_month: 0.8062,
          type: 'dummy'
        }
      ]
    end

    def plans_at(_location_str_id)
      plans
    end
  end
end
