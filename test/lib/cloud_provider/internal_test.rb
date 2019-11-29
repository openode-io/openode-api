
require 'test_helper'

class InternalTest < ActiveSupport::TestCase
  test 'calc_cost_per_month' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')
    id = internal_provider.plans.first[:internal_id]

    assert_equal internal_provider.calc_cost_per_month(id, 50).between?(0.40, 0.41), true
    assert_equal internal_provider.calc_cost_per_month(id, 1024).between?(8.25, 8.27), true
    assert_equal internal_provider.calc_cost_per_month(id, 2048).between?(16.51, 16.52), true
  end

  test 'calc_cost_per_month for open source' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')
    
    cost = internal_provider.calc_cost_per_month(Website::OPEN_SOURCE_ACCOUNT_TYPE, 50)
    assert_equal cost, 0
  end

  test 'calc_cost_per_hour' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')
    id = internal_provider.plans.first[:internal_id]

    assert_equal internal_provider.calc_cost_per_hour(id, 50).between?(0.0005, 0.0006), true
  end

  test 'calc_cost_per_minute' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')
    id = internal_provider.plans.first[:internal_id]

    assert_equal internal_provider.calc_cost_per_minute(id, 50).between?(0.0000089, 0.0000091), true
  end

  test 'plans' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')
    id = internal_provider.plans.first[:internal_id]

    plans = internal_provider.plans
    assert_equal plans.length, 8
    assert_equal plans[0][:id], 'sandbox'
    assert_equal plans[0][:internal_id], 'free'
    assert_equal plans[0][:short_name], 'sandbox'
    assert_equal plans[0][:human_id], 'sandbox'
    assert_equal plans[0][:name], 'Sandbox'
    assert_equal plans[0][:ram], 100
    assert_equal plans[0][:storage], 1000
    assert_equal plans[0][:bandwidth], 10
    assert_equal plans[0][:cost_per_minute], internal_provider.calc_cost_per_minute(id, 100)
    assert_equal plans[0][:cost_per_hour], internal_provider.calc_cost_per_hour(id, 100)
    assert_equal plans[0][:cost_per_month], internal_provider.calc_cost_per_month(id, 100)
  end

  test 'plans_at with existing' do
    provider = CloudProvider::Manager.instance.first_of_type('internal')
    provider.initialize_locations

    location = Location.find_by str_id: 'canada'

    plans = provider.plans_at(location.str_id)

    assert_equal plans.length, 8

    plans.each do |plan|
      assert_equal plan[:type], CloudProvider::Internal::TYPE
    end
  end
end
