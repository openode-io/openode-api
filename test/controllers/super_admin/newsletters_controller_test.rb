
require 'test_helper'

class SuperAdmin::NewslettersControllerTest < ActionDispatch::IntegrationTest
  test "index with matches" do
    get '/super_admin/newsletters?search=lo newslet',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["title"], "Hello newsletter"
  end
end
