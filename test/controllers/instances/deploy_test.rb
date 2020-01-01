
require 'test_helper'

class InstancesControllerDeployTest < ActionDispatch::IntegrationTest
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
  end

  test '/instances/:instance_id/restart requires minimum CLI version' do
    post "/instances/#{@website.site_name}/restart",
         as: :json,
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body['error'], 'Deprecated'
  end

  test '/instances/:instance_id/restart should not be starting' do
    website = Website.find_by! site_name: 'testsite'
    website.change_status!(Website::STATUS_STARTING)

    post "/instances/#{website.site_name}/restart?" \
         "version=#{InstancesController::MINIMUM_CLI_VERSION}",
         as: :json,
         headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body['error'], 'The instance must be in status'
  end

  test '/instances/:instance_id/restart forbidden' do
    w, = prepare_forbidden_test(Website::PERMISSION_PLAN)

    post "/instances/#{w.site_name}/restart?version=#{InstancesController::MINIMUM_CLI_VERSION}",
         as: :json,
         headers: default_headers_auth

    assert_response :forbidden
  end
end
