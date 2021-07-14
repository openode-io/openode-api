require 'test_helper'

class SuspendedUserTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test 'suspended user should fail' do
    user = default_user
    user.suspended = 1
    user.save!

    # user 1
    get "/instances/", as: :json, headers: default_headers_auth

    assert_response :unauthorized
  end
end