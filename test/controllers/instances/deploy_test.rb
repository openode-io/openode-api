
require 'test_helper'

class InstancesControllerDeployTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/restart requires minimum CLI version" do
    post "/instances/testsite/restart", as: :json, headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "Deprecated"
  end

  test "/instances/:instance_id/restart should not be starting" do
  	website = Website.find_by! site_name: "testsite"
  	website.status = Website::STATUS_STARTING
  	website.save

    post "/instances/testsite/restart?version=#{InstancesController::MINIMUM_CLI_VERSION}", 
    	as: :json, 
    	headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "The instance must be in status"
  end

end
