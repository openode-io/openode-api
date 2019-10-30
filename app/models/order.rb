class Order < ApplicationRecord
  serialize :content, JSON

  belongs_to :user

  validates :user, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, presence: true
  validates :content, presence: true
  validates :gateway, presence: true

  before_create :apply_coupon
  after_create :add_user_credits
  after_create :send_confirmation_email

  def apply_coupon
    first_unused_coupon = user.first_unused_coupon

    return unless first_unused_coupon

    self.amount = amount * (1.0 + first_unused_coupon.extra_ratio_rebate)

    content['coupon'] = first_unused_coupon

    user.use_coupon!(first_unused_coupon)
  end

  def add_user_credits
    nb_credits = Website.cost_price_to_credits(amount)

    user.credits += nb_credits
    user.save
  end

  def send_confirmation_email
    OrderMailer.with(order: self, comment: '').confirmation.deliver_now

    # extra copy for admin purpose
    OrderMailer.with(
      order: self,
      comment: '',
      email_to: ENV['DEFAULT_EMAIL']
    ).confirmation.deliver_now
  end
end
