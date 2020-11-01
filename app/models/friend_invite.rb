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
  validate :validate_email_cannot_be_itself

  def validate_user_limit
    errors.add(:user, 'Reached friend invites limit') if user.friend_invites.count > 100
  end

  def validate_email_cannot_be_itself
    errors.add(:user, 'Cannot be yourself') if user.email.downcase == email.downcase
  end
end
