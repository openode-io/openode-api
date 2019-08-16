require 'test_helper'

class GlobalControllerTest < ActionDispatch::IntegrationTest
  test "/global/test" do
    get "/global/test", as: :json

    assert_response :success
  end

  test "/global/available-configs" do
    get "/global/available-configs", as: :json

    assert_response :success

    expected_variables = [
      "SSL_CERTIFICATE_PATH",
      "SSL_CERTIFICATE_KEY_PATH",
      "REDIR_HTTP_TO_HTTPS",
      "MAX_BUILD_DURATION",
      "SKIP_PORT_CHECK"
    ]

    expected_variables.each do |var|
      assert_equal response.parsed_body.any? { |v| v["variable"] == var }, true
    end

  end
end
