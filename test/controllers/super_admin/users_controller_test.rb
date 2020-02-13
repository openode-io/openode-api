
require 'test_helper'

class SuperAdmin::UsersControllerTest < ActionDispatch::IntegrationTest
  test "with matches by email" do
    user = User.last
    get "/super_admin/users?search=#{user.email}",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["id"], user.id
    assert_equal response.parsed_body[0]["email"], user.email
  end

  test "with matches by id" do
    user = User.last
    get "/super_admin/users?search=#{user.id}",
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["id"], user.id
  end

  test "without match" do
    get '/super_admin/users?search=invalid1234',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end
end
