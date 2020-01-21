require 'test_helper'

class GlobalNotificationTest < ActiveSupport::TestCase
  test 'create' do
    n = GlobalNotification.create!(
      level: Notification::LEVEL_CRITICAL,
      content: 'hello world ! ;)'
    )

    assert_equal n.type, "GlobalNotification"
    assert_equal n.level, Notification::LEVEL_CRITICAL
    assert_equal n.content, 'hello world ! ;)'
  end
end
