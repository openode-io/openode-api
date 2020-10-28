class FriendInvite < ApplicationRecord
  belongs_to :user
  belongs_to :order, optional: true

  STATUS_PENDING = "pending"
  STATUS_APPROVED = "approved"

  STATUSES = [
    STATUS_PENDING,
    STATUS_APPROVED
  ].freeze

  validates :email, presence: true
  validates :email, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :status, inclusion: { in: STATUSES }
  validate :validate_user_limit

  def validate_user_limit
    errors.add(:user, 'Reached friend invites limit') if user.friend_invites.count > 100
  end
end
