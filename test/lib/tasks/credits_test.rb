require 'test_helper'

class LibTasksCreditsTest < ActiveSupport::TestCase
  setup do
    reset_emails
    set_all_offline
  end

  def set_all_offline
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save
    end
  end

  test "spend - no online site" do
    invoke_task "credits:online_spend"

    assert_equal ActionMailer::Base.deliveries.count, 0
  end

  test "spend - one to process, happy path" do
    website = default_website
    website.status = Website::STATUS_ONLINE
    website.save!
    credits_begin = website.user.reload.credits

    invoke_task "credits:online_spend"

    assert_equal ActionMailer::Base.deliveries.count, 0
    assert_equal website.user.reload.credits < credits_begin, true

    assert_equal website.events.length, 0
  end

  test "spend - one to process, one lacks credits" do
    website = default_website
    website.status = Website::STATUS_ONLINE
    website.save!

    website.user.credits = 0
    website.user.save!

    invoke_task "credits:online_spend"

    mail_sent = ActionMailer::Base.deliveries.last

    assert_includes mail_sent.body.raw_source, 'due to a lack of credit'
    assert_includes mail_sent.body.raw_source, website.site_name
    assert_includes mail_sent.to, website.user.email

    # check that it has stop instance event
    last_event = website.events.last
    assert_equal last_event.obj["title"], "Stopping instance (lacking credits)"
    assert_equal last_event.obj["api_result"]["result"], "success"
  end
end
