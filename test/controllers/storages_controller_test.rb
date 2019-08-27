require 'test_helper'

class StoragesControllerTest < ActionDispatch::IntegrationTest
  test "POST /instances/:instance_id/increase_storage with valid info" do
    payload = { amount_gb: 2 }
    post "/instances/testsite/increase-storage?location_str_id=canada",
      params: payload, as: :json, headers: default_headers_auth

    # TODO
    assert_response :success
    # assert_equal response.parsed_body["site_name"], "testsite"
  end

  test "POST /instances/:instance_id/increase_storage with negative gb" do
    payload = { amount_gb: -2 }
    post "/instances/testsite/increase-storage?location_str_id=canada",
      params: payload, as: :json, headers: default_headers_auth

    assert_response :bad_request
  end
end
