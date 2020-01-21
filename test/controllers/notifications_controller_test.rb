require 'test_helper'

class NotificationsControllerTest < ActionDispatch::IntegrationTest
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

  test 'PATCH /notifications/:id disallow if not super admin' do
    notification = GlobalNotification.create!(
      level: Notification::LEVEL_WARNING,
      content: 'hello world ! ;)'
    )

    patch "/notifications/#{notification.id}",
          params: {},
          as: :json,
          headers: default_headers_auth

    assert_response :unauthorized
  end

  test 'PATCH /notifications/:id happy path' do
    notification = WebsiteNotification.create!(
      level: Notification::LEVEL_WARNING,
      content: 'hello world ! ;)',
      website: default_website
    )

    content = {
      level: Notification::LEVEL_INFO,
      content: 'hello world2!'
    }

    patch "/notifications/#{notification.id}",
          params: content,
          as: :json,
          headers: super_admin_headers_auth

    assert_response :success

    assert_equal response.parsed_body['level'], Notification::LEVEL_INFO

    notification.reload
    assert_equal notification.level, Notification::LEVEL_INFO
    assert_equal notification.content, 'hello world2!'
  end

  test 'PATCH /notifications/:id should not be able to change website' do
    notification = WebsiteNotification.create!(
      level: Notification::LEVEL_WARNING,
      content: 'hello world ! ;)',
      website: default_website
    )

    content = {
      level: Notification::LEVEL_INFO,
      content: 'hello world2!',
      website_id: default_custom_domain_website.id
    }

    patch "/notifications/#{notification.id}",
          params: content,
          as: :json,
          headers: super_admin_headers_auth

    assert_response :success

    notification.reload
    assert_equal notification.website_id, default_website.id
  end
end
