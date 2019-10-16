
require 'test_helper'

class LocationsTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/locations with subdomain" do
    get "/instances/testsite/locations", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["id"], "canada"
  end

  test "/instances/:instance_id/add-location fail if already exists" do
  	w = default_website

    post "/instances/testsite/add-location", 
    	as: :json, 
    	params: { str_id: "canada" },
    	headers: default_headers_auth

    assert_response :bad_request
  end

  test "/instances/:instance_id/add-location fail already have a location" do
  	w = default_website

    post "/instances/testsite/add-location", 
    	as: :json, 
    	params: { str_id: "usa" },
    	headers: default_headers_auth

    assert_response :bad_request
    assert_includes response.parsed_body["error"], "Multi location is not currently supported"
  end

end
