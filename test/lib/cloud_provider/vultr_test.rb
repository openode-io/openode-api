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

	test "create ssh key" do
		website_location = default_website_location
		website_location.gen_ssh_key!
		provider = CloudProvider::Manager.instance.first_of_type("vultr")
		firewall = provider.find_firewall_group("base")

		provider.create_ssh_key!("hello-world", website_location.secret[:public_key])
	end

	test "allocate" do
		website = default_website
		website.account_type = "plan-201"
		website.site_name = "thisisatest.com"
		website.domains = ["thisisatest.com"]
		website.domain_type = "custom_domain"
		website.save
		website_location = website.website_locations.first
		website_location.location.str_id = "alaska-6"
		website_location.location.save

		provider = CloudProvider::Manager.instance.first_of_type("vultr")

		provider.allocate({ website: website, website_location: website_location })

		website.reload

		assert_equal website.data["privateCloudInfo"]["SUBID"], "30303641"
		assert_equal website.data["privateCloudInfo"]["SSHKEYID"], "5da3d3a1affa7"
	end
end
