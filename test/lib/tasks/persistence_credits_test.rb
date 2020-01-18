require 'test_helper'

class LibTasksCreditsTest < ActiveSupport::TestCase
  setup do
    reset_emails
  end

  test "spend persistence - one to process, does not lack credits" do
    reset_all_extra_storage

    website = default_website
    website.status = Website::STATUS_OFFLINE
    website.save!
    wl = website.website_locations.first
    wl.change_storage!(2)

    website.user.credits = 1000
    website.user.save!

    invoke_task "credits:persistence_spend"

    mail_sent = ActionMailer::Base.deliveries.last
    assert_nil mail_sent

    assert_equal website.events.count, 0
    assert_in_delta website.user.reload.credits, 999.96, 0.01
  end

  test "spend persistence - one to process, lacks credits" do
    reset_all_extra_storage

    website = default_website
    website.status = Website::STATUS_OFFLINE
    website.save!
    wl = website.website_locations.first
    wl.change_storage!(2)

    website.user.credits = 0
    website.user.save!

    invoke_task "credits:persistence_spend"

    mail_sent = ActionMailer::Base.deliveries.last
    assert_includes mail_sent.body.raw_source, 'the persistence associated'
    assert_includes mail_sent.body.raw_source, website.site_name
    assert_includes mail_sent.to, website.user.email

    assert_includes website.events.last.obj['title'], 'Destroying persistence'
    assert_includes website.events.last.obj['api_result'].to_s, 'success'

    assert_equal website.user.reload.credits, 0
  end
end
