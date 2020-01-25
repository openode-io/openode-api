require 'test_helper'

class UserNotificationsControllerTest < ActionDispatch::IntegrationTest
  test '/notifications/ without notification' do
    Notification.all.each(&:destroy)

    get '/notifications/',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['notifications'], []
    assert_equal response.parsed_body['nb_unviewed'], 0
  end

  test '/notifications/ with one global and one website' do
    ViewedNotification.all.each(&:destroy)

    new_notification = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    get '/notifications/',
        as: :json,
        headers: default_headers_auth

    notifications = response.parsed_body['notifications']

    assert_response :success
    assert_equal notifications.length, 2
    assert_equal notifications[0]['id'], new_notification.id
    assert_equal notifications[0]['content'], 'hello world ! ;)'
    assert_equal notifications[1]['content'], 'hello world'
    assert_equal response.parsed_body['nb_unviewed'], 2
  end

  test '/notifications/ with one unviewed' do
    ViewedNotification.all.each(&:destroy)

    new_notification = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    ViewedNotification.create(
      notification: new_notification,
      user: default_user
    )

    get '/notifications/',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['nb_unviewed'], 1
  end

  test '/notifications/ with specified limit' do
    GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    get '/notifications/?limit=1',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['notifications'].length, 1
  end

  test '/notifications/ with one type' do
    global_notif = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    get '/notifications/?types=GlobalNotification',
        as: :json,
        headers: default_headers_auth

    assert_response :success
    assert_equal response.parsed_body['notifications'].length, 1
    assert_equal response.parsed_body['notifications'][0]['id'], global_notif.id
  end
end
