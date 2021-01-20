
require 'test_helper'

class LibTasksSubscriptionTest < ActiveSupport::TestCase
  test "subscription clean - happy path" do
    w = default_website
    w.status = Website::STATUS_OFFLINE
    w.save!

    SubscriptionWebsite.destroy_all

    subscription = Subscription.create!(user: w.user, quantity: 1, active: true)
    sw = SubscriptionWebsite.create!(website: w, subscription: subscription, quantity: 1)

    invoke_task "subscription:clean"

    assert_nil SubscriptionWebsite.find_by(id: sw.id)
  end

  test "subscription clean - is starting should not be removed" do
    w = default_website
    w.account_type = "auto"
    w.status = Website::STATUS_STARTING
    w.save!

    SubscriptionWebsite.destroy_all

    subscription = Subscription.create!(user: w.user, quantity: 1, active: true)
    sw = SubscriptionWebsite.create!(website: w, subscription: subscription, quantity: 1)

    invoke_task "subscription:clean"

    assert SubscriptionWebsite.find_by(id: sw.id)
  end

  test "subscription clean - non auto plan should be removed" do
    w = default_website
    w.account_type = "first"
    w.status = Website::STATUS_STARTING
    w.save!

    SubscriptionWebsite.destroy_all

    subscription = Subscription.create!(user: w.user, quantity: 1, active: true)
    sw = SubscriptionWebsite.create!(website: w, subscription: subscription, quantity: 1)

    invoke_task "subscription:clean"

    assert_nil SubscriptionWebsite.find_by(id: sw.id)
  end

  test "subscription check expiration - has one expired" do
    w = default_website
    w.status = Website::STATUS_STARTING
    w.save!

    SubscriptionWebsite.destroy_all
    Subscription.destroy_all

    subscription1 = Subscription.create!(
      user: w.user,
      quantity: 1,
      active: true,
      expires_at: Time.zone.now + 10.days
    )
    subscription2 = Subscription.create!(
      user: w.user,
      quantity: 1,
      active: true,
      expires_at: Time.zone.now - 1.day
    )

    invoke_task "subscription:check_expirations"

    assert_equal subscription1.reload.active, true
    assert_equal subscription2.reload.active, false
  end
end
