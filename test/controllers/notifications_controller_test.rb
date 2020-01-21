require 'test_helper'

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test 'POST /notifications disallow if not super admin' do
    post '/notifications/',
         params: {},
         as: :json,
         headers: default_headers_auth

    assert_response :unauthorized
  end

  test 'POST /notifications happy path' do
    website = default_website

    content = {
      type: 'WebsiteNotification',
      level: Notification::LEVEL_WARNING,
      content: 'hello world!',
      website_id: website.id
    }

    post '/notifications/',
         params: content,
         as: :json,
         headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body['content'], 'hello world!'

    notification = WebsiteNotification.find(response.parsed_body['id'])
    assert_equal notification.type, 'WebsiteNotification'
    assert_equal notification.level, Notification::LEVEL_WARNING
    assert_equal notification.content, 'hello world!'
    assert_equal notification.website, website
  end
end
