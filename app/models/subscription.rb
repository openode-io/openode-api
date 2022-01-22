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

      # if the website is online, start the subscription usage
      Subscription.start_using_subscription(user, website) if website.online?
    end
  end

  def quantity_used
    subscription_websites.sum(:quantity)
  end

  def fully_used?
    quantity_used >= quantity
  end

  def self.clean_subscriptions_usage(website)
    website.subscription_websites.destroy_all unless website.auto_plan?
  end

  def self.start_using_subscription(user, website)
    return nil unless user.subscriptions.activated.count.positive?

    # already using one?
    sw = SubscriptionWebsite.find_by(website: website)
    return { subscription: sw.subscription, subscription_website: sw } if sw

    subscription = nil
    subscription_website = nil
    quantity_needed = 1

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

  def cancel
    return false unless subscription_id

    latest_order = user.orders.where(
      "content LIKE ?", "%#{subscription_id}%"
    ).order(id: :desc).first

    return false unless latest_order

    self.expires_at = latest_order.created_at + 1.month
    save

    true
  rescue StandardError => e
    Ex::Logger.error(e, "Can't cancel the subscription #{id}")
    false
  end
end
