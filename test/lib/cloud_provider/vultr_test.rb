require 'test_helper'



class CloudProviderVultrTest < ActiveSupport::TestCase
	test "plans" do
		provider = CloudProvider::Manager.instance.first_of_type("vultr")

		plans = provider.plans

		assert_equal plans.length, 8
		assert_equal plans[0][:id], "1024-MB-201"
		assert_equal plans[0][:internal_id], "1024-MB-201"
		assert_equal plans[0][:short_name], "1024-MB-201"
		assert_equal plans[0][:type], CloudProvider::Vultr::TYPE
		assert_equal plans[0][:name], "1024 MB RAM,25 GB SSD,1.00 TB BW"
		assert_equal plans[0][:ram], 1024
		assert_equal plans[0][:cost_per_hour], 0.01075268817204301
		assert_equal plans[0][:cost_per_month], 8.0

		assert_equal plans[7][:id], "98304-MB-208"
	end
end
