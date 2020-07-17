
require 'test_helper'

class InternalTest < ActiveSupport::TestCase
  test 'calc_cost_per_month' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')

    assert_equal internal_provider.calc_cost_per_month(50).between?(0.5, 0.5), true
    assert_equal internal_provider.calc_cost_per_month(1024).between?(10.24, 10.24), true
    assert_equal internal_provider.calc_cost_per_month(2048).between?(20.48, 20.48), true
  end

  test 'calc_cost_per_hour' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')

    assert_in_delta internal_provider.calc_cost_per_hour(50), 0.00067, 0.00001
  end

  test 'calc_cost_per_minute' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')

    puts "internal_provider.calc_cost_per_minute(50) #{internal_provider.calc_cost_per_minute(50)}"
    assert_in_delta internal_provider.calc_cost_per_minute(50), 0.0000112, 0.000001
  end

  test 'plans' do
    internal_provider = CloudProvider::Manager.instance.first_of_type('internal')

    plans = internal_provider.plans
    assert_equal plans.length, 7
    assert_equal plans[0][:internal_id], 'open_source'
    assert_equal plans[0][:cost_per_minute], internal_provider.calc_cost_per_minute(100)
    assert_equal plans[0][:cost_per_hour], internal_provider.calc_cost_per_hour(100)
    assert_equal plans[0][:cost_per_month], internal_provider.calc_cost_per_month(100)
  end

  test 'plans_at with existing' do
    provider = CloudProvider::Manager.instance.first_of_type('internal')
    provider.initialize_locations

    location = Location.find_by str_id: 'canada'

    plans = provider.plans_at(location.str_id)

    assert_equal plans.length, 7

    plans.each do |plan|
      assert_equal plan[:type], CloudProvider::Internal::TYPE
    end
  end
end
