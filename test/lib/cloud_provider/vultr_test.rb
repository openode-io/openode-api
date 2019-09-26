require 'test_helper'



class CloudProviderVultrTest < ActiveSupport::TestCase

	

	test "plans" do
		provider = CloudProvider::Manager.instance.first_of_type("vultr")

		plans = provider.plans

		puts "plans af #{plans.inspect}"

		#assert_equal plans.length, 7
		#assert_equal plans[0][:id], "sandbox"
		#assert_equal plans[0][:internal_id], "free"
		#assert_equal plans[0][:short_name], "sandbox"
		#assert_equal plans[0][:human_id], "sandbox"
		#assert_equal plans[0][:name], "Sandbox"
		#assert_equal plans[0][:ram], 100
		#assert_equal plans[0][:storage], 1000
		#assert_equal plans[0][:bandwidth], 10
		#assert_equal plans[0][:cost_per_minute], internal_provider.calc_cost_per_minute(100)
		#assert_equal plans[0][:cost_per_hour], internal_provider.calc_cost_per_hour(100)
		#assert_equal plans[0][:cost_per_month], internal_provider.calc_cost_per_month(100)
	end
end
