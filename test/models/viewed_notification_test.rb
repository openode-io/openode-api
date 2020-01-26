require 'test_helper'

class ViewedNotificationTest < ActiveSupport::TestCase
  test "viewed_by? - not viewed" do
    ViewedNotification.all.each(&:destroy)

    notification = Notification.first

    assert_equal notification.viewed_by?(default_user), false
  end

  test "viewed_by? - viewed" do
    ViewedNotification.all.each(&:destroy)



    notification = GlobalNotification.create(
      level: Notification::LEVEL_WARNING,
      content: 'what'
    )

    ViewedNotification.create(
      notification: notification,
      user: default_user
    )


    assert_equal notification.viewed_by?(default_user), true
  end
end
