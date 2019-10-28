class Order < ApplicationRecord
  serialize :content, JSON

  belongs_to :user

  validates :user, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payment_status, presence: true
  validates :content, presence: true

  before_create :apply_coupon
  after_create :send_confirmation_email

  def apply_coupon
    # if any
  end

  def send_confirmation_email; end
end
