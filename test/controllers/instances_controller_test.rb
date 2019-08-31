require 'test_helper'

class InstancesControllerTest < ActionDispatch::IntegrationTest
  test "/instances/ with param token" do
    user = default_user

    get "/instances/?token=#{user.token}", as: :json

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["site_name"], "testsite"
    assert_equal response.parsed_body[0]["status"], "online"
  end

  test "/instances/ with header token" do
    w = Website.find_by site_name: "testsite"
    w.domains = []
    w.save
    get "/instances/", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["site_name"], "testsite"
    assert_equal response.parsed_body[0]["status"], "online"

    assert_equal response.parsed_body[0]["domains"], []
  end

  test "/instances/:instance_id with valid site name" do
    get "/instances/testsite", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["site_name"], "testsite"
    assert_equal response.parsed_body["status"], "online"
  end

  test "/instances/:instance_id with non existent site name" do
    get "/instances/testsite10", as: :json, headers: default_headers_auth

    assert_response :not_found
  end

end
