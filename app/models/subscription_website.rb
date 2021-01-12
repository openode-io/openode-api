class SubscriptionWebsite < ApplicationRecord
  belongs_to :subscription
  belongs_to :website

  validates :subscription, presence: true
  validates :website, presence: true

  def activated?
    subscription&.active
  end
end
