class Subscription < ApplicationRecord
  belongs_to :user

  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
