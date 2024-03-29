class Order < ApplicationRecord
  serialize :content, JSON

  belongs_to :user

  validates :user, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, presence: true
  validates :content, presence: true
  validates :gateway, presence: true

  REGULAR_GATEWAYS = %w[paypal credit]
  CRYPTO_GATEWAYS = %w[btc ether bch stellar cro]

  validates :gateway, inclusion: { in: (REGULAR_GATEWAYS + CRYPTO_GATEWAYS) }

  before_create :apply_coupon
  after_create :add_user_credits
  after_create :add_credit_for_crypto_payments
  after_create :send_confirmation_email

  def apply_coupon
    first_unused_coupon = user.first_unused_coupon

    return unless first_unused_coupon

    self.amount = amount * (1.0 + first_unused_coupon.extra_ratio_rebate)

    content['coupon'] = first_unused_coupon

    user.use_coupon!(first_unused_coupon)
  end

  def add_credit_for_crypto_payments
    if CRYPTO_GATEWAYS.include?(gateway)
      Order.create(
        user_id: user_id,
        content: { "type" => "customer", "reason" => "Credit for order ##{id}" },
        amount: amount * 0.05,
        payment_status: "Completed",
        gateway: "credit"
      )
    end
  end

  def add_user_credits
    unless is_subscription
      nb_credits = Website.cost_price_to_credits(amount)

      user.credits += nb_credits
      user.save
    end
  end

  def send_confirmation_email
    OrderMailer.with(order: self, comment: '').confirmation.deliver_now

    # extra copy for admin purpose
    OrderMailer.with(
      order: self,
      comment: content&.dig('comment') || content&.dig(:comment),
      email_to: ENV['DEFAULT_EMAIL']
    ).confirmation.deliver_now
  end
end
