require 'test_helper'

class LibTasksCreditsTest < ActiveSupport::TestCase
  setup do
    reset_emails
  end

  test "spend persistence - one to process, does not lack credits" do
    CreditActionLoop.destroy_all
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

    credit_loop = CreditActionLoop.last
    assert credit_loop
    assert_equal credit_loop.type, "CreditActionLoopPersistenceSpend"
    assert_equal credit_loop.credit_actions.count, 1
    assert_equal credit_loop.credit_actions.first.website.id, website.id
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

  test "spend persistence - addon with persistence, lack credit" do
    reset_all_extra_storage

    website = default_website
    website.status = Website::STATUS_OFFLINE
    website.save!

    website.user.credits = 0
    website.user.save!

    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['requires_persistence'] = true
    addon.obj['persistent_path'] = "/var/www"
    addon.obj['required_fields'] = ['persistent_path']
    addon.save!

    WebsiteAddon.create!(
      id: 980_191_099,
      name: 'hi-world',
      account_type: 'second',
      website: website,
      addon: addon,
      obj: {
        attrib: 'val1'
      },
      storage_gb: 1,
      status: WebsiteAddon::STATUS_ONLINE
    )

    invoke_task "credits:persistence_spend"

    mail_sent = ActionMailer::Base.deliveries.last
    assert_includes mail_sent.body.raw_source, 'the persistence associated'
    assert_includes mail_sent.body.raw_source, website.site_name
    assert_includes mail_sent.to, website.user.email

    assert_equal website.user.reload.credits, 0
  end
end
