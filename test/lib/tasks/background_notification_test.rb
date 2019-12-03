
require 'test_helper'

class LibTasksBackgroundNotificationTest < ActiveSupport::TestCase
  setup do
    reset_emails
  end

  test "after_one_day_registration" do
    invoke_task "background_notification:after_one_day_registration"

    mail_sent = ActionMailer::Base.deliveries.first

    assert_equal ActionMailer::Base.deliveries.count, 1

    assert_equal mail_sent.subject, 'New opeNode User Support'
    assert_includes mail_sent.body.raw_source, 'Thank you for choosing opeNode'
    assert_includes mail_sent.to, "myadmin@thisisit.com"
  end

  test "low_credit" do
    u_to_switch_low = User.find_by email: 'myadmin@thisisit.com'
    u_to_switch_low.notified_low_credit = true
    u_to_switch_low.save

    invoke_task "background_notification:low_credit"

    mail_sent = ActionMailer::Base.deliveries.first

    assert_equal ActionMailer::Base.deliveries.count, 1

    assert_equal mail_sent.subject, 'Your opeNode account has low credit'
    assert_includes mail_sent.body.raw_source, 'Please note that your account now has less than 1.5'
    assert_includes mail_sent.to, "myadmin2@thisisit.com"

    u_to_switch_low.reload
    assert_equal u_to_switch_low.notified_low_credit, false
  end
end
