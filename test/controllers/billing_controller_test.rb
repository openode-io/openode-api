require 'test_helper'

class BillingControllerTest < ActionDispatch::IntegrationTest
  test '/billing/orders with valid' do
    user = default_user
    get '/billing/orders', headers: default_headers_auth, as: :json

    assert_equal user.token, default_headers_auth[:'x-auth-token']

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]['amount'], 5
    assert_equal response.parsed_body[1]['amount'], 10
  end

  test '/billing/orders with user without order' do
    user = User.find_by token: '12345678'
    get '/billing/orders', headers: headers_auth(user.token), as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end

  test '/billing/orders not logged in' do
    get '/billing/orders', headers: {}, as: :json

    assert_response :unauthorized
  end
end
