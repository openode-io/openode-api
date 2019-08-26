require 'test_helper'

class StoragesControllerTest < ActionDispatch::IntegrationTest
  test "POST /instances/:instance_id/increase_storage with valid info" do
    payload = { }
    post "/instances/testsite/increase-storage", params: payload, as: :json, headers: default_headers_auth

    # TODO
    assert_response :success
    # assert_equal response.parsed_body["site_name"], "testsite"
  end
end
