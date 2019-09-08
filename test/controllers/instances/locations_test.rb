
require 'test_helper'

class LocationsTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/locations with subdomain" do
    get "/instances/testsite/locations", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["id"], "canada"
  end

end
