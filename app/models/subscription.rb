class Subscription < ApplicationRecord
  belongs_to :user
  has_many :subscription_websites
  has_many :credit_actions

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  after_create :do_after_create

  scope :activated, -> { where(active: true) }

  def do_after_create
    return if user.websites.count > quantity

    user.websites.each do |website|
      website.account_type = Website::AUTO_ACCOUNT_TYPE
      website.save(validate: false)
    end
  end

  def quantity_used
    subscription_websites.sum(:quantity)
  end

  def fully_used?
    quantity_used >= quantity
  end

  def self.start_using_subscription(user, website)
    return nil unless user.subscriptions.activated.count.positive?

    # already using one?
    sw = SubscriptionWebsite.find_by(website: website)
    return { subscription: sw.subscription, subscription_website: sw } if sw

    subscription = nil
    subscription_website = nil
    quantity_needed = website.website_locations.first.replicas

    ActiveRecord::Base.transaction do
      subscription = user.subscriptions.reload.activated.find do |s|
        s.quantity - s.quantity_used >= quantity_needed
      end

      raise "Can't find subscription" unless subscription

      subscription_website = SubscriptionWebsite.create!(
        subscription: subscription,
        website: website,
        quantity: quantity_needed
      )
    end

    {
      subscription: subscription,
      subscription_website: subscription_website
    }
  rescue StandardError => e
    Ex::Logger.error(e, "Can't start using subscription")
    nil
  end

  def self.stop_using_subscription(website)
    SubscriptionWebsite.where(website: website).destroy_all
  end
end
