
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
    w.status = Website::STATUS_STARTING
    w.save!

    SubscriptionWebsite.destroy_all

    subscription = Subscription.create!(user: w.user, quantity: 1, active: true)
    sw = SubscriptionWebsite.create!(website: w, subscription: subscription, quantity: 1)

    invoke_task "subscription:clean"

    assert SubscriptionWebsite.find_by(id: sw.id)
  end
end
