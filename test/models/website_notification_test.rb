require 'test_helper'

class WebsiteNotificationTest < ActiveSupport::TestCase
  test 'create' do
    wn = WebsiteNotification.create!(
      level: Notification::LEVEL_WARNING,
      content: 'hello world ! ;)',
      website: default_website
    )

    assert_equal wn.type, "WebsiteNotification"
    assert_equal wn.level, Notification::LEVEL_WARNING
    assert_equal wn.content, 'hello world ! ;)'
    assert_equal wn.website_id, default_website.id
  end

  test 'fail create if missing website' do
    wn = WebsiteNotification.create(
      level: Notification::LEVEL_WARNING,
      content: 'hello world ! ;)'
    )

    assert_equal wn.valid?, false
  end

  test 'fail create if invalid level' do
    wn = WebsiteNotification.create(
      level: 'what',
      content: 'hello world ! ;)',
      website: default_website
    )

    assert_equal wn.valid?, false
  end
end
