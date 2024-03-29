require 'test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  test "quantity_used - happy path" do
    SubscriptionWebsite.destroy_all
    s = Subscription.first
    SubscriptionWebsite.create!(website_id: default_website.id, subscription_id: s.id, quantity: 1)

    assert_equal s.quantity_used, 1
  end

  test "fully_used? - not" do
    SubscriptionWebsite.destroy_all
    s = Subscription.first
    s.user_id = default_user.id
    s.quantity = 2
    s.save!
    SubscriptionWebsite.create!(website_id: default_website.id, subscription_id: s.id, quantity: 1)

    assert_equal s.fully_used?, false
  end

  test "fully_used? - is" do
    SubscriptionWebsite.destroy_all
    s = Subscription.first
    s.user_id = default_user.id
    s.quantity = 1
    s.save!
    SubscriptionWebsite.create!(website_id: default_website.id, subscription_id: s.id, quantity: 1)

    assert_equal s.fully_used?, true
  end

  test "quantity_used - none" do
    SubscriptionWebsite.destroy_all
    s = Subscription.first

    assert_equal s.quantity_used, 0
  end

  test "start_using_subscription - happy path" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations
    user = website.user

    s = Subscription.create!(user_id: user.id, quantity: 3, active: true)

    website.reload

    user.websites.each do |w|
      assert_equal w.account_type, Website::AUTO_ACCOUNT_TYPE
    end

    result = Subscription.start_using_subscription(user, website)

    assert_equal result[:subscription], s
    assert_equal result[:subscription_website].quantity, 1
    assert_equal result[:subscription_website].subscription, s
    assert_equal result[:subscription_website].website, website
  end

  test "clean_subscriptions_usage - happy path" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations
    user = website.user

    s = Subscription.create!(user_id: user.id, quantity: 3, active: true)

    website.reload

    website.account_type = Website::AUTO_ACCOUNT_TYPE
    website.save!

    result = Subscription.start_using_subscription(user, website)

    assert_equal result[:subscription], s

    website.account_type = "first"
    website.save!

    Subscription.clean_subscriptions_usage(website)

    assert website.reload.subscription_websites, []
  end

  test "clean_subscriptions_usage - no cleanup if auto" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations
    user = website.user

    s = Subscription.create!(user_id: user.id, quantity: 3, active: true)

    website.reload

    website.account_type = Website::AUTO_ACCOUNT_TYPE
    website.save!

    result = Subscription.start_using_subscription(user, website)

    assert_equal result[:subscription], s

    Subscription.clean_subscriptions_usage(website)

    assert website.reload.subscription_websites.first, result[:subscription_website]
  end

  test "auto set account type on create - happy path" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.status = "N/A"
    website.save!

    website.website_locations

    user = website.user
    Website.where.not(id: website.id).destroy_all

    Subscription.create!(user_id: user.id, quantity: 1, active: true)

    website.reload

    assert_equal website.account_type, "auto"
    assert SubscriptionWebsite.count.zero?
  end

  test "auto set account type on create - start using subscription if online" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.status = "online"
    website.save!

    website.website_locations

    user = website.user
    Website.where.not(id: website.id).destroy_all

    subscription = Subscription.create!(user_id: user.id, quantity: 1, active: true)

    website.reload

    assert_equal website.account_type, "auto"
    assert SubscriptionWebsite.count == 1
    assert_equal SubscriptionWebsite.last.website, website
    assert_equal SubscriptionWebsite.last.subscription, subscription
  end

  test "cancel - happy path" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations

    user = website.user
    order = user.orders.last

    order.is_subscription = true
    subscription_id = "I-123456FFFDDF"

    order.content = "{\"recurring_payment_id\":\"#{subscription_id}\"}"
    order.save!

    Website.where.not(id: website.id).destroy_all

    s = Subscription.create!(
      user_id: user.id,
      quantity: 1,
      active: true,
      subscription_id: subscription_id
    )

    result = s.cancel

    s.reload

    assert result
    assert s.expires_at >= (order.created_at + 1.month - 1.minute)
  end

  test "cancel - no subscription order" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations

    user = website.user
    order = user.orders.last

    order.is_subscription = true
    subscription_id = "I-123456FFFDDF"

    order.content = "{\"hello\":\"world\"}"
    order.save!

    Website.where.not(id: website.id).destroy_all

    s = Subscription.create!(
      user_id: user.id,
      quantity: 1,
      active: true,
      subscription_id: subscription_id
    )

    result = s.cancel

    s.reload

    assert_not result
    assert_nil s.expires_at
  end

  test "auto set account type on create - without order should work" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations

    user = website.user
    Website.where.not(id: website.id).destroy_all
    user.orders.destroy_all

    Subscription.create!(user_id: user.id, quantity: 1, active: true)

    website.reload

    assert_equal website.account_type, "auto"
  end

  test "auto set account type on create - not do if too many sites" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.account_type = "first"
    website.save!

    website.website_locations
    user = website.user

    Subscription.create!(user_id: user.id, quantity: 1, active: true)

    website.reload

    assert_equal website.account_type, "first"
  end

  test "start_using_subscription - if website already using one, return it" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    website.website_locations
    user = website.user

    s = Subscription.create!(user_id: user.id, quantity: 2, active: true)

    result = Subscription.start_using_subscription(user, website)
    result2 = Subscription.start_using_subscription(user, website)

    assert_equal result[:subscription], s
    assert_equal result[:subscription_website].quantity, 1
    assert_equal result[:subscription_website].subscription, s
    assert_equal result[:subscription_website].website, website

    assert_equal result2[:subscription], s
    assert_equal result2[:subscription_website], result[:subscription_website]
  end

  test "stop_using_subscription - happy path" do
    SubscriptionWebsite.destroy_all
    Subscription.destroy_all
    website = default_website
    user = website.user

    s = Subscription.create!(user_id: user.id, quantity: 2, active: true)
    Subscription.create!(user_id: user.id, quantity: 1, active: true)

    result = Subscription.start_using_subscription(user, website)

    assert result

    Subscription.stop_using_subscription(website)

    assert_equal s.subscription_websites.reload.count, 0
  end
end
