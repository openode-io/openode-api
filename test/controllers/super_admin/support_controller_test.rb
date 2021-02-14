require 'test_helper'

class SuperAdmin::SupportControllerTest < ActionDispatch::IntegrationTest
  test "send contact with message" do
    post '/super_admin/support/contact',
         params: { hi: 'world', message: 'this is a message' },
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success
  end
end
