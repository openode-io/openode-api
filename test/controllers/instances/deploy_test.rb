
require 'test_helper'

class InstancesControllerDeployTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/restart requires minimum CLI version" do
    post "/instances/testsite/restart", as: :json, headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "Deprecated"
  end

  test "/instances/:instance_id/restart should not be starting" do
  	website = Website.find_by! site_name: "testsite"
    website.change_status!(Website::STATUS_STARTING)

    post "/instances/testsite/restart?version=#{InstancesController::MINIMUM_CLI_VERSION}", 
    	as: :json, 
    	headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "The instance must be in status"
  end

  test "/instances/:instance_id/restart should not allow when no credit" do
    website = Website.find_by! site_name: "testsite"
    website.user.credits = 0
    website.user.save

    post "/instances/testsite/restart", 
      as: :json, 
      params: base_params,
      headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "No credit available"
  end

  test "/instances/:instance_id/restart should not allow when user not activated" do
    website = Website.find_by! site_name: "testsite"
    website.user.activated = false
    website.user.save

    post "/instances/testsite/restart", 
      as: :json, 
      params: base_params,
      headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "User account not yet activated"
  end

  test "/instances/:instance_id/restart should not allow when user suspended" do
    website = Website.find_by! site_name: "testsite"
    website.user.suspended = true
    website.user.save

    post "/instances/testsite/restart", 
      as: :json, 
      params: base_params,
      headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "User suspended"
  end

  test "/instances/:instance_id/restart" do
    #set_dummy_secrets_to(LocationServer.all)

    #website = Website.find_by! site_name: "testsite"

    #post "/instances/testsite/restart", 
    #  as: :json, 
    #  params: base_params,
    #  headers: default_headers_auth

    #assert_response :success
    #assert_includes response.parsed_body["error"], "User suspended"
  end

end
