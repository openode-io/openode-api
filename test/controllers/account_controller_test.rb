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

  test "/account/register valid" do
    account = {
      email: "myadminvalidregister@thisisit.com",
      password: "Helloworld234",
      password_confirmation: "Helloworld234"
    }

    post "/account/register", params: account, as: :json

    assert_response :success

    user = User.find(response.parsed_body["id"])

    assert_equal user.email, account[:email]
    assert_equal user.token, response.parsed_body["token"]
  end

  test "/account/register password does not match" do
    account = {
      email: "myadminvalidregister@thisisit.com",
      password: "Helloworld234",
      password_confirmation: "Helloworld234567"
    }

    post "/account/register", params: account, as: :json

    assert response.status >= 400
  end
end
