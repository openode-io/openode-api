require 'test_helper'

class StoragesControllerTest < ActionDispatch::IntegrationTest
  test "POST /instances/:instance_id/increase_storage with valid info" do
    payload = { amount_gb: 2 }
    post "/instances/testsite/increase-storage?location_str_id=canada",
      params: payload, as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["result"], "success"
    assert_equal response.parsed_body["Extra Storage (GB)"], 3
  end

  test "POST /instances/:instance_id/increase_storage with negative gb" do
    payload = { amount_gb: -2 }
    post "/instances/testsite/increase-storage?location_str_id=canada",
      params: payload, as: :json, headers: default_headers_auth

    assert_response :bad_request
    assert response.parsed_body["error"].include?("must be positive")
  end

  test "POST /instances/:instance_id/increase_storage with too large extra storage" do
    payload = { amount_gb: 10 }
    post "/instances/testsite/increase-storage?location_str_id=canada",
      params: payload, as: :json, headers: default_headers_auth

    assert_response :unprocessable_entity
    assert response.parsed_body["error"].include?("Extra storage")
  end
end
