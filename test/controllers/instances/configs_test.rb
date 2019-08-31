
require 'test_helper'

class ConfigsTest < ActionDispatch::IntegrationTest

  test "/instances/:instance_id/get-config with valid variable" do
    w = Website.find_by site_name: "testsite"
    w.configs = { SKIP_PORT_CHECK: "true" }
    w.save
    get "/instances/testsite/get-config?variable=SKIP_PORT_CHECK", as: :json, headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body["result"], "success"
    assert_equal response.parsed_body["value"], "true"
  end

  test "/instances/:instance_id/get-config with invalid variable" do
    get "/instances/testsite/get-config?variable=invalidvar", as: :json, headers: default_headers_auth
    assert_response :bad_request
  end

  test "/instances/:instance_id/set-config with valid variable, enum, website type" do
    post "/instances/testsite/set-config",
      as: :json,
      params: { variable: "REDIR_HTTP_TO_HTTPS", value: "true" },
      headers: default_headers_auth

    assert_response :success
    w = Website.find_by site_name: "testsite"

    assert_equal w.configs["REDIR_HTTP_TO_HTTPS"], "true"
    assert_equal w.redir_http_to_https, true
  end

  test "/instances/:instance_id/set-config with valid variable, enum" do
    post "/instances/testsite/set-config",
      as: :json,
      params: { variable: "SKIP_PORT_CHECK", value: "true" },
      headers: default_headers_auth

    assert_response :success
    w = Website.find_by site_name: "testsite"

    assert_equal w.configs["SKIP_PORT_CHECK"], "true"
  end

end
