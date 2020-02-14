
require 'test_helper'

class SuperAdmin::WebsitesControllerTest < ActionDispatch::IntegrationTest
  test "with matches" do
    get '/super_admin/websites?search=testsite',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 2
    assert_equal response.parsed_body[0]["site_name"], "testsite"
    assert_equal response.parsed_body[1]["site_name"], "testsite2"
  end

  test "without match" do
    get '/super_admin/websites?search=ompleteasdf',
        as: :json,
        headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 0
  end
end
