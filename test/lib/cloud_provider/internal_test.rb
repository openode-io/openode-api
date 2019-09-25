require 'test_helper'

class InternalTest < ActiveSupport::TestCase

	# calc_cost_per_month

	test "calc_cost_per_month" do
		internal_provider = CloudProvider::Manager.instance.first_of_type("internal")

		assert_equal internal_provider.calc_cost_per_month(50).between?(0.40, 0.41), true
		assert_equal internal_provider.calc_cost_per_month(1024).between?(8.25, 8.27), true
		assert_equal internal_provider.calc_cost_per_month(2048).between?(16.51, 16.52), true
	end

	test "calc_cost_per_hour" do
		internal_provider = CloudProvider::Manager.instance.first_of_type("internal")

		assert_equal internal_provider.calc_cost_per_hour(50).between?(0.0005, 0.0006), true
	end

	test "calc_cost_per_minute" do
		internal_provider = CloudProvider::Manager.instance.first_of_type("internal")

		assert_equal internal_provider.calc_cost_per_minute(50).between?(0.0000089, 0.0000091), true
	end

	test "plans" do
		internal_provider = CloudProvider::Manager.instance.first_of_type("internal")

		plans = internal_provider.plans
		assert_equal plans.length, 7
		assert_equal plans[0][:id], "sandbox"
		assert_equal plans[0][:internal_id], "free"
		assert_equal plans[0][:short_name], "sandbox"
		assert_equal plans[0][:human_id], "sandbox"
		assert_equal plans[0][:name], "Sandbox"
		assert_equal plans[0][:ram], 100
		assert_equal plans[0][:storage], 1000
		assert_equal plans[0][:bandwidth], 10
		assert_equal plans[0][:cost_per_minute], internal_provider.calc_cost_per_minute(100)
		assert_equal plans[0][:cost_per_hour], internal_provider.calc_cost_per_hour(100)
		assert_equal plans[0][:cost_per_month], internal_provider.calc_cost_per_month(100)
	end
end
