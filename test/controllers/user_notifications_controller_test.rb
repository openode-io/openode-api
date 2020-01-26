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

  test '/notifications/ with specified website' do
    GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    websites = default_user.websites_with_access

    websites.each do |w|
      WebsiteNotification.create!(
        website: w,
        level: Notification::LEVEL_WARNING,
        content: 'warning, warning'
      )
    end

    w = websites.first

    get "/notifications/?website=#{w.id}",
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body['notifications'].length, 2

    response.parsed_body['notifications'].each do |notification|
      assert notification['website_id'] == w.id ||
             (notification['website_id'].nil? &&
               notification['content'] == 'hello world ! ;)')
    end

    assert_equal response.parsed_body['nb_unviewed'], 2
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

  test '/notifications/view with list of notifications - happy path' do
    global_notif_1 = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    global_notif_2 = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    post '/notifications/view',
         as: :json,
         headers: default_headers_auth,
         params: { notifications: [global_notif_1.id, global_notif_2.id] }

    assert_response :success
    assert_equal response.parsed_body['nb_marked'], 2

    ViewedNotification.find_by! user: default_user, notification: global_notif_1
    ViewedNotification.find_by! user: default_user, notification: global_notif_2
  end

  test '/notifications/view with list of notifications - partial view' do
    global_notif_1 = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    global_notif_2 = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    ViewedNotification.create(
      user: default_user,
      notification: global_notif_1
    )

    post '/notifications/view',
         as: :json,
         headers: default_headers_auth,
         params: { notifications: [global_notif_1.id, global_notif_2.id] }

    assert_response :success
    assert_equal response.parsed_body['nb_marked'], 1
    assert_equal response.parsed_body['marked'][0]['id'], global_notif_2.id
  end

  test '/notifications/view without notification' do
    Notification.all.destroy_all

    post '/notifications/view',
         as: :json,
         headers: default_headers_auth,
         params: { notifications: [] }

    assert_response :success
    assert_equal response.parsed_body['nb_marked'], 0
  end

  test '/notifications/view all - happy path' do
    Notification.all.destroy_all

    global_notif_1 = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    global_notif_2 = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    post '/notifications/view?all=true',
         as: :json,
         headers: default_headers_auth,
         params: { notifications: [] }

    assert_response :success
    assert_equal response.parsed_body['nb_marked'], 2

    ViewedNotification.find_by! user: default_user, notification: global_notif_1
    ViewedNotification.find_by! user: default_user, notification: global_notif_2
  end
end
