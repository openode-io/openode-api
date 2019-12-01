
require 'test_helper'

class LibTasksBackgroundNotificationTest < ActiveSupport::TestCase
  test "after_one_day_registration" do
    ActionMailer::Base.deliveries = []

    invoke_task "background_notification:after_one_day_registration"

    mail_sent = ActionMailer::Base.deliveries.first

    assert_equal ActionMailer::Base.deliveries.count, 1

    assert_equal mail_sent.subject, 'New opeNode User Support'
    assert_includes mail_sent.body.raw_source, 'Thank you for choosing opeNode'
    assert_includes mail_sent.to, "myadmin@thisisit.com"
  end
end
