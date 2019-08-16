require 'test_helper'

class AccountControllerTest < ActionDispatch::IntegrationTest
  test "/account/getToken with valid creds" do
    account = { email: "myadmin@thisisit.com", password: "testpw" }
    post "/account/getToken", params: account, as: :json

    assert_response :success
    assert_equal response.parsed_body, "1234s56789"
  end

  test "/account/getToken with not found email" do
    account = { email: "invalid@thisisit.com", password: "testpw" }
    post "/account/getToken", params: account, as: :json

    assert_response :not_found
  end

  test "/account/getToken with invalid password" do
    account = { email: "myadmin@thisisit.com", password: "invalid" }
    post "/account/getToken", params: account, as: :json

    assert_response :unauthorized
  end
end
