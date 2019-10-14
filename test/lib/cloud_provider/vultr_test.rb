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

	test "plans_at with existing" do
		provider = CloudProvider::Manager.instance.first_of_type("vultr")
		provider.initialize_locations

		location = Location.find_by str_id: "singapore-40"

		plans = provider.plans_at(location.str_id)

		assert_equal plans.length, 7

		find_one = plans.find { |plan| plan[:id] == "1024-MB-201" }

		assert_equal find_one[:id], "1024-MB-201"

		plans.each do |plan|
			assert_equal plan[:type], CloudProvider::Vultr::TYPE
		end
	end

	test "os_list" do
		provider = CloudProvider::Manager.instance.first_of_type("vultr")
		oses = provider.os_list

		assert_equal oses.length, 25
		assert_equal oses[0]["name"], "CentOS 6 x64"
	end

	test "find startup script" do
		provider = CloudProvider::Manager.instance.first_of_type("vultr")
		script = provider.find_startup_script("init base debian")

		assert_equal script["name"], "init base debian"
	end

	test "find firewall" do
		provider = CloudProvider::Manager.instance.first_of_type("vultr")
		firewall = provider.find_firewall_group("base")

		assert_equal firewall["description"], "base"
	end

end
