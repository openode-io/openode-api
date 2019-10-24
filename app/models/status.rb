class Status < ApplicationRecord
  validates :name, uniqueness: true

  scope :with_status, ->(status) { where(status: status) }
end
