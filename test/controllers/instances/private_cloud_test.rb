require 'test_helper'

class PrivateCloudTest < ActionDispatch::IntegrationTest
	def prepare_custom_domain_with_vultr
		website = default_website
		website.account_type = "plan-201"
		website.site_name = "thisisatest.com"
		website.domains = ["thisisatest.com"]
		website.domain_type = "custom_domain"
		website.cloud_type = "private-cloud"
		website.save!
		website_location = website.website_locations.first
		website_location.location.str_id = "alaska-6"
		website_location.location.save!

		[website, website_location]
	end

	test "POST /instances/:instance_id/allocate" do
		website, website_location = prepare_custom_domain_with_vultr

	    post "/instances/thisisatest.com/allocate?location_str_id=alaska-6",
	      as: :json,
	      params: { },
	      headers: default_headers_auth

	    website.reload

	    assert_response :success
	    assert_equal response.parsed_body["status"], "Instance creating..."
	    assert_equal website.data["privateCloudInfo"]["SUBID"], "30303641"
	    assert_equal website.data["privateCloudInfo"]["SSHKEYID"], "5da3d3a1affa7"
	end

	test "POST /instances/:instance_id/allocate fail if already allocated" do
		website, website_location = prepare_custom_domain_with_vultr
		website.data = { "privateCloudInfo" => { "SUBID" => "asdf"} }
		website.save

	    post "/instances/thisisatest.com/allocate?location_str_id=alaska-6",
	      as: :json,
	      params: { },
	      headers: default_headers_auth

	    assert_response :success
	    assert_equal response.parsed_body["success"], "Instance already allocated"
	end

	test "POST /instances/:instance_id/allocate fail no credit" do
		website, website_location = prepare_custom_domain_with_vultr
		website.user.credits = 0
		website.user.save

	    post "/instances/thisisatest.com/allocate?location_str_id=alaska-6",
	      as: :json,
	      params: { },
	      headers: default_headers_auth

	    assert_response :bad_request
	end
end
