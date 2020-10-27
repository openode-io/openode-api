class FriendInvite < ApplicationRecord
  belongs_to :user
  belongs_to :order, optional: true

  STATUS_PENDING = "pending"
  STATUS_APPROVED = "approved"

  STATUSES = [
    STATUS_PENDING,
    STATUS_APPROVED
  ].freeze

  validates :status, inclusion: { in: STATUSES }
end
