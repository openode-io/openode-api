class CreditAction < ApplicationRecord
  belongs_to :user
  belongs_to :website

  validate :verify_enough_credits

  TYPE_CONSUME_PLAN = 'consume-plan'
  TYPE_CONSUME_BLUE_GREEN = 'consume-blue-green'
  TYPE_CONSUME_STORAGE = 'consume-storage'
  TYPE_CONSUME_BANDWIDTH = 'consume-bandwidth'
  ACTION_TYPES = [
    TYPE_CONSUME_PLAN,
    TYPE_CONSUME_STORAGE,
    TYPE_CONSUME_BANDWIDTH,
    TYPE_CONSUME_BLUE_GREEN
  ].freeze

  validates :action_type, inclusion: { in: ACTION_TYPES }

  def verify_enough_credits
    unless (user.credits - credits_spent).positive?
      errors.add(:credits, 'No credits remaining')
    end
  end

  def self.consume!(website, action_type, credits_spent, opts = {})
    cred_action = CreditAction.create!(
      user: website.user,
      website: website,
      action_type: action_type,
      credits_spent: credits_spent
    )

    if opts[:with_user_update]
      website.user.credits -= credits_spent
      website.user.save!
    end

    cred_action.credits_remaining = website.user.credits
    cred_action.save(validate: false)

    cred_action
  end
end
