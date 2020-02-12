
require 'test_helper'

class SuperAdmin::OrdersControllerTest < ActionDispatch::IntegrationTest
  test "with matches" do
    get '/super_admin/orders?search=omplete',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]["email"], "myadmin@thisisit.com"
  end

  test "without match" do
    get '/super_admin/orders?search=ompleteasdf',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end
end
