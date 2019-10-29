class Coupon < ApplicationRecord
  validates :str_id, presence: true
  validates :str_id, uniqueness: true
  validates :extra_ratio_rebate, presence: true
  validates :nb_days_valid, presence: true
end
